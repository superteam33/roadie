class Api::V1::SlackWebhookController < Api::V1::ApplicationController
  require_relative '../../../services/openai_service'
  # Skip authentication for webhooks
  skip_before_action :authenticate_user!, only: [:events, :interactive]
  
  # Slack event subscription endpoint
  def events
    # Handle URL verification challenge
    if params[:challenge]
      render plain: params[:challenge]
      return
    end
    
    # Verify Slack request signature
    unless verify_slack_signature
      render json: { error: 'Invalid signature' }, status: :unauthorized
      return
    end
    
    event_data = JSON.parse(request.body.read)
    
    # Handle different event types
    case event_data['type']
    when 'event_callback'
      handle_event_callback(event_data['event'])
    when 'url_verification'
      render plain: event_data['challenge']
    else
      render json: { message: 'Event type not handled' }
    end
  end
  
  # Interactive components (buttons, modals, etc.)
  def interactive
    unless verify_slack_signature
      render json: { error: 'Invalid signature' }, status: :unauthorized
      return
    end
    
    payload = JSON.parse(params[:payload])
    
    case payload['type']
    when 'block_actions'
      handle_block_actions(payload)
    when 'view_submission'
      handle_view_submission(payload)
    else
      render json: { message: 'Interactive type not handled' }
    end
  end
  
  private
  
  def handle_event_callback(event)
    # Skip processing if this is a bot message to prevent infinite loops
    return render json: { message: 'Bot message ignored' } if event['bot_id'] || event['subtype'] == 'bot_message'
    
    case event['type']
    when 'app_mention'
      handle_app_mention(event)
    when 'message'
      handle_message(event)
    else
      Rails.logger.info "Unhandled event type: #{event['type']}"
    end
    
    render json: { message: 'Event processed' }
  end
  
  def handle_app_mention(event)
    # Skip if the message is just a mention without any other content
    text_without_mention = event['text'].gsub(/<@[^>]+>/, '').strip
    return if text_without_mention.empty?
    
    # Check if this is a thread reply
    if event['thread_ts']
      # This is a thread reply mentioning @roadie
      process_thread_messages(event)
    else
      # This is a direct mention, process normally
      process_direct_mention(event)
    end
  end
  
  def handle_message(event)
    # Handle regular messages that might be in threads
    return unless event['thread_ts'] && event['text']&.include?('@roadie')
    
    # Skip if the message is just a mention without any other content
    text_without_mention = event['text'].gsub(/<@[^>]+>/, '').strip
    return if text_without_mention.empty?
    
    process_thread_messages(event)
  end
  
  def process_thread_messages(event)
    # Check if this is a roadmap or task creation request
    text_lower = event['text'].downcase
    
    # More specific detection for task creation
    is_task_creation = text_lower.include?('create task') || text_lower.include?('add task') || 
                      text_lower.include?('new task') || text_lower.include?('bot create')
    
    # More specific detection for roadmap requests
    is_roadmap = text_lower.include?('roadmap') || text_lower.include?('build') || 
                text_lower.include?('develop') || text_lower.include?('plan')
    
    if is_task_creation || is_roadmap
      # This is a roadmap or task creation request, process it directly
      process_roadmap_request(event)
    else
      # Only send hello response if this is a direct mention, not just any message in thread
      if event['type'] == 'app_mention'
        send_hello_response(event)
      end
    end
    
    # Get the thread messages
    thread_messages = fetch_thread_messages(event['channel'], event['thread_ts'])
    
    # Process the entire thread
    IntegrationWebhookJob.perform_later(
      'slack_thread',
      event['text'],
      {
        channel: event['channel'],
        thread_ts: event['thread_ts'],
        user: event['user'],
        team: event['team'],
        thread_messages: thread_messages,
        event_type: 'thread_mention'
      },
      find_user_by_slack_id(event['user']).id
    )
  end
  
  def process_direct_mention(event)
    # Check if this is a roadmap or task creation request
    text_lower = event['text'].downcase
    
    # More specific detection for task creation
    is_task_creation = text_lower.include?('create task') || text_lower.include?('add task') || 
                      text_lower.include?('new task') || text_lower.include?('bot create')
    
    # More specific detection for roadmap requests
    is_roadmap = text_lower.include?('roadmap') || text_lower.include?('build') || 
                text_lower.include?('develop') || text_lower.include?('plan')
    
    if is_task_creation || is_roadmap
      process_roadmap_request(event)
    else
      # Send immediate hello response for other requests
      send_hello_response(event)
    end
    
    # Also process through the integration system
    IntegrationWebhookJob.perform_later(
      'slack',
      event['text'],
      {
        channel: event['channel'],
        user: event['user'],
        team: event['team'],
        event_type: 'direct_mention'
      },
      find_user_by_slack_id(event['user']).id
    )
  end
  
  def fetch_thread_messages(channel, thread_ts)
    # Use Slack Web API to fetch thread messages
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    begin
      response = slack_client.conversations_replies(
        channel: channel,
        ts: thread_ts
      )
      
      response['messages'].map do |msg|
        {
          text: msg['text'],
          user: msg['user'],
          ts: msg['ts'],
          thread_ts: msg['thread_ts'],
          timestamp: Time.at(msg['ts'].to_f)
        }
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error fetching thread messages: #{e.message}"
      []
    end
  end
  
  def find_user_by_slack_id(slack_user_id)
    # Find user by their Slack ID
    user = User.find_by(slack_user_id: slack_user_id)
    
    if user
      Rails.logger.info "Found user by Slack ID: #{user.full_name} (#{user.email})"
      user
    else
      Rails.logger.warn "No user found with Slack ID: #{slack_user_id}, using first user as fallback"
      # Use the first user as fallback for now
      fallback_user = User.first
      if fallback_user
        Rails.logger.info "Using fallback user: #{fallback_user.full_name} (#{fallback_user.email})"
        fallback_user
      else
        Rails.logger.error "No users found in database!"
        nil
      end
    end
  end
  
  def verify_slack_signature
    # Verify Slack request signature for security
    return true if Rails.env.development? # Skip in development
    
    signature = request.headers['X-Slack-Signature']
    timestamp = request.headers['X-Slack-Request-Timestamp']
    body = request.body.read
    
    # Check timestamp to prevent replay attacks
    return false if Time.now.to_i - timestamp.to_i > 300 # 5 minutes
    
    # Verify signature
    expected_signature = 'v0=' + OpenSSL::HMAC.hexdigest(
      'SHA256',
      ENV['SLACK_SIGNING_SECRET'],
      "v0:#{timestamp}:#{body}"
    )
    
    Rack::Utils.secure_compare(signature, expected_signature)
  end
  
  def handle_block_actions(payload)
    # Handle interactive button clicks, etc.
    render json: { message: 'Block actions handled' }
  end
  
  def handle_view_submission(payload)
    # Handle modal submissions
    render json: { message: 'View submission handled' }
  end
  
  def process_roadmap_request(event)
    # Check rate limiting to prevent infinite loops
    return if rate_limited?(event)
    
    # Generate roadmap using AI service factory
    begin
      ai_service = AiServiceFactory.create_service
      response = ai_service.generate_roadmap(
        event['text'],
        {
          channel_name: get_channel_name(event['channel']),
          user_name: get_user_info(event['user'])[:name],
          participants: [get_user_info(event['user'])]
        }
      )
      
      Rails.logger.info "OpenAI response: #{response.class} - #{response.is_a?(String) ? response[0..100] + '...' : response.inspect}"
      
      # Check if this is a task creation response
      if response.is_a?(Hash) && (response['tasks'] || response[:tasks])
        handle_task_creation(event, response)
      elsif response && response.is_a?(Hash) && response[:error]
        Rails.logger.error "Task creation failed: #{response[:error]}"
        send_error_response(event, response[:error])
      else
        Rails.logger.warn "Response is nil or unexpected format: #{response.inspect}"
      end
    rescue => e
      Rails.logger.error "Error generating roadmap: #{e.message}"
      # Don't post error messages to Slack, just log them
    end
  end
  
  def send_roadmap_acknowledgment(event)
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    begin
      slack_client.chat_postMessage(
        channel: event['channel'],
        text: "🗺️ Generating your roadmap... This might take a moment!",
        thread_ts: event['ts']
      )
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error sending roadmap acknowledgment: #{e.message}"
    end
  end
  
  def send_roadmap_response(event, roadmap)
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    begin
      Rails.logger.info "send_roadmap_response called with roadmap type: #{roadmap.class}"
      
      # Split long messages if needed (Slack has a 4000 character limit)
      if roadmap.is_a?(Hash) && roadmap[:error]
        text = "❌ #{roadmap[:error]}"
      else
        text = roadmap.to_s
        if text.length > 3000
          # Split into chunks
          chunks = text.scan(/.{1,3000}/)
          chunks.each_with_index do |chunk, index|
            prefix = index == 0 ? "" : "_(continued...)_\n\n"
            response = slack_client.chat_postMessage(
              channel: event['channel'],
              text: prefix + chunk,
              thread_ts: event['ts']
            )
            Rails.logger.info "Posted chunk #{index + 1}/#{chunks.length}: #{response.inspect}"
          end
          return
        end
      end
      
      response = slack_client.chat_postMessage(
        channel: event['channel'],
        text: text,
        thread_ts: event['ts']
      )
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error sending roadmap response: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
    rescue => e
      Rails.logger.error "Unexpected error sending roadmap response: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
    end
  end
  
  def send_error_response(event, error_message)
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    begin
      slack_client.chat_postMessage(
        channel: event['channel'],
        text: "❌ #{error_message}",
        thread_ts: event['ts']
      )
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error sending error response: #{e.message}"
    end
  end
  
  # Helpers
  def get_user_info(user_id)
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    begin
      response = slack_client.users_info(user: user_id)
      user = response['user']
      {
        id: user['id'],
        name: user['real_name'] || user['name'],
        display_name: user.dig('profile', 'display_name') || user['name'],
        email: user.dig('profile', 'email')
      }
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error fetching user info: #{e.message}"
      { id: user_id, name: 'Unknown User' }
    end
  end
  
  def get_channel_name(channel_id)
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    begin
      response = slack_client.conversations_info(channel: channel_id)
      response.dig('channel', 'name') || channel_id
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error fetching channel info: #{e.message}"
      channel_id
    end
  end
  
  def send_hello_response(event)
    # Send a simple hello response back to the channel
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    begin
      slack_client.chat_postMessage(
        channel: event['channel'],
        text: "👋 Hello! I'm @roadie, your AI project management assistant. How can I help you today?",
        thread_ts: event['ts'] # Reply in the same thread
      )
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error sending hello response: #{e.message}"
    end
  end

  def handle_task_creation(event, task_data)
    # Find the user who made the request
    user = find_user_by_slack_id(event['user'])
    return unless user

    # Initialize Slack client and thread service
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    slack_service = SlackThreadService.new(user)
    
    # Post initial placeholder message
    placeholder_ts = slack_service.post_placeholder_message(
      event['channel'],
      event['ts'],
      "🤖 *Analyzing your request and creating tasks...*\n\n_Processing..._"
    )
    
    return unless placeholder_ts # Exit if we couldn't post the placeholder

    # Build the progress message that we'll update
    progress_lines = ["🤖 *Creating tasks from your request...*\n"]
    
    # Create the tasks using TaskCreationService with progress callback
    task_service = TaskCreationService.new(user)
    result = task_service.create_task_from_slack_request(
      event['text'],
      {
        channel_name: get_channel_name(event['channel']),
        user_name: get_user_info(event['user'])[:name]
      }
    ) do |progress|
      # This callback is called after each task is created
      task_line = "\n✅ *Task #{progress[:index]}/#{progress[:total]}:* #{progress[:task_title]}"
      progress_lines << task_line
      
      # Update the Slack message with the current progress
      slack_service.update_message(
        event['channel'],
        placeholder_ts,
        progress_lines.join("\n")
      )
      
      # Small delay to make the updates visible (optional, can be removed for faster updates)
      sleep(0.3)
    end

    # Final message update with complete summary
    if result[:success]
      tasks = result[:tasks] || result['tasks']
      final_message = build_final_task_summary(tasks, progress_lines)
      slack_service.update_message(
        event['channel'],
        placeholder_ts,
        final_message
      )
    else
      error_message = "🤖 *Task creation process*\n\n❌ *Error:* #{result[:error]}"
      slack_service.update_message(
        event['channel'],
        placeholder_ts,
        error_message
      )
    end
  end

  def build_final_task_summary(tasks, progress_lines)
    # Build a nice summary with all created tasks
    summary = ["🎉 *Successfully created #{tasks.length} task(s)!*\n"]
    
    tasks.each_with_index do |task, index|
      summary << "\n*#{index + 1}. #{task[:title]}*"
      summary << "   📝 #{task[:description][0..100]}#{'...' if task[:description].length > 100}"
      summary << "   🎯 Priority: #{task[:priority]} | Status: #{task[:status]}"
      if task[:assignee_uuid]
        summary << "   👤 Assigned"
      end
    end
    
    summary << "\n\n✨ _All tasks have been added to your project!_"
    summary.join("\n")
  end

  def send_task_creation_success(event, tasks)
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    # Format the tasks response in the required JSON format
    tasks_json = tasks.map do |task|
      {
        "title": task[:title],
        "description": task[:description],
        "status": task[:status],
        "priority": task[:priority],
        "epic_uuid": task[:epic_uuid],
        "assignee_uuid": task[:assignee_uuid],
        "due_date": task[:due_date]
      }
    end

    begin
      slack_client.chat_postMessage(
        channel: event['channel'],
        text: "✅ #{tasks.length} task(s) created successfully!\n\n```json\n#{JSON.pretty_generate(tasks_json)}\n```",
        thread_ts: event['ts']
      )
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error sending task creation success: #{e.message}"
    end
  end

  def send_task_creation_error(event, error_message)
    slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    begin
      slack_client.chat_postMessage(
        channel: event['channel'],
        text: "❌ Failed to create task: #{error_message}",
        thread_ts: event['ts']
      )
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error sending task creation error: #{e.message}"
    end
  end

  def rate_limited?(event)
    # Create a unique key for this event to prevent duplicate processing
    event_key = "#{event['channel']}_#{event['user']}_#{event['ts']}"
    
    # Check if we've already processed this event in the last 30 seconds
    cache_key = "slack_event_#{event_key}"
    
    if Rails.cache.exist?(cache_key)
      Rails.logger.info "Rate limiting: Event already processed recently - #{event_key}"
      return true
    end
    
    # Mark this event as processed for 30 seconds
    Rails.cache.write(cache_key, true, expires_in: 30.seconds)
    
    # Additional check: prevent processing if the message is from a bot
    if event['bot_id'] || event['subtype'] == 'bot_message'
      Rails.logger.info "Rate limiting: Ignoring bot message"
      return true
    end
    
    # Additional check: prevent processing if message is too old (older than 5 minutes)
    message_time = Time.at(event['ts'].to_f)
    if message_time < 5.minutes.ago
      Rails.logger.info "Rate limiting: Message too old - #{message_time}"
      return true
    end
    
    false
  end
end
