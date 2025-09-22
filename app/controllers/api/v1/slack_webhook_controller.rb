class Api::V1::SlackWebhookController < Api::V1::ApplicationController
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
    
    process_thread_messages(event)
  end
  
  def process_thread_messages(event)
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
    # Send immediate hello response
    send_hello_response(event)
    
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
    # You might need to add a slack_user_id field to your User model
    User.find_by(slack_user_id: slack_user_id) || User.first # Fallback for now
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
end
