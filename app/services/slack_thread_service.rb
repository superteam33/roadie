class SlackThreadService
  include HTTParty
  
  def initialize(user)
    @user = user
    @slack_client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
  end
  
  def process_thread_mention(thread_data)
    {
      channel: thread_data[:channel],
      thread_ts: thread_data[:thread_ts],
      user: thread_data[:user],
      team: thread_data[:team],
      thread_messages: thread_data[:thread_messages],
      summary: generate_thread_summary(thread_data[:thread_messages]),
      agent_instructions: extract_agent_instructions(thread_data[:thread_messages]),
      context: build_context(thread_data)
    }
  end
  
  def fetch_thread_messages(channel, thread_ts)
    begin
      response = @slack_client.conversations_replies(
        channel: channel,
        ts: thread_ts
      )
      
      response['messages'].map do |msg|
        {
          text: msg['text'],
          user: msg['user'],
          ts: msg['ts'],
          thread_ts: msg['thread_ts'],
          timestamp: Time.at(msg['ts'].to_f),
          user_info: get_user_info(msg['user'])
        }
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error fetching thread messages: #{e.message}"
      []
    end
  end
  
  def post_thread_response(channel, thread_ts, message)
    Rails.logger.info "post_thread_response called with channel: #{channel}, thread_ts: #{thread_ts}, message length: #{message&.length}"
    begin
      response = @slack_client.chat_postMessage(
        channel: channel,
        text: message,
        thread_ts: thread_ts
      )
      Rails.logger.info "Successfully posted message to Slack: #{response.inspect}"
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error posting thread response: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
    rescue => e
      Rails.logger.error "Unexpected error posting thread response: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
    end
  end

  def post_placeholder_message(channel, thread_ts, text = "🤖 Working on it...")
    Rails.logger.info "Posting placeholder message to channel: #{channel}, thread_ts: #{thread_ts}"
    begin
      response = @slack_client.chat_postMessage(
        channel: channel,
        text: text,
        thread_ts: thread_ts
      )
      Rails.logger.info "Posted placeholder message: #{response.inspect}"
      # Return the timestamp of the posted message so we can update it later
      response['ts']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error posting placeholder message: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Unexpected error posting placeholder: #{e.message}"
      nil
    end
  end

  def update_message(channel, message_ts, new_text)
    Rails.logger.info "Updating message in channel: #{channel}, ts: #{message_ts}"
    begin
      response = @slack_client.chat_update(
        channel: channel,
        ts: message_ts,
        text: new_text
      )
      Rails.logger.info "Successfully updated message: #{response.inspect}"
      response
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error updating message: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
      nil
    rescue => e
      Rails.logger.error "Unexpected error updating message: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
      nil
    end
  end
  
  private
  
  def generate_thread_summary(messages)
    # Create a summary of the thread for context
    message_texts = messages.map do |msg|
      user_name = msg[:user_info]&.dig(:name) || 'Unknown User'
      "#{user_name}: #{msg[:text]}"
    end
    message_texts.join("\n")
  end
  
  def extract_agent_instructions(messages)
    # Look for specific instructions or commands in the thread
    instructions = []
    
    messages.each do |msg|
      text = msg[:text].downcase
      
      # Look for common agent commands
      if text.include?('@roadie')
        # Extract the part after @roadie
        parts = msg[:text].split('@roadie')
        if parts.length > 1
          instruction = parts[1].strip
        instructions << {
          instruction: instruction,
          user: msg[:user_info]&.dig(:name) || 'Unknown User',
          timestamp: msg[:timestamp]
        }
        end
      end
      
      # Look for specific keywords that might indicate agent tasks
      if text.match?(/create|generate|build|make|update|status|progress|task|epic|prd|roadmap/)
        instructions << {
          instruction: msg[:text],
          user: msg[:user_info]&.dig(:name) || 'Unknown User',
          timestamp: msg[:timestamp],
          type: 'implicit_command'
        }
      end
    end
    
    instructions
  end
  
  def build_context(thread_data)
    {
      channel_name: get_channel_name(thread_data[:channel]),
      thread_url: build_thread_url(thread_data),
      participants: extract_participants(thread_data[:thread_messages]),
      message_count: thread_data[:thread_messages].length,
      duration: calculate_thread_duration(thread_data[:thread_messages])
    }
  end
  
  def get_user_info(user_id)
    begin
      response = @slack_client.users_info(user: user_id)
      user = response['user']
      {
        id: user['id'],
        name: user['real_name'] || user['name'],
        display_name: user['display_name'] || user['name'],
        email: user['profile']['email']
      }
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error fetching user info: #{e.message}"
      { id: user_id, name: 'Unknown User' }
    end
  end
  
  def get_channel_name(channel_id)
    begin
      response = @slack_client.conversations_info(channel: channel_id)
      response['channel']['name']
    rescue Slack::Web::Api::Errors::SlackError => e
      Rails.logger.error "Error fetching channel info: #{e.message}"
      channel_id
    end
  end
  
  def build_thread_url(thread_data)
    "https://app.slack.com/client/#{thread_data[:team]}/#{thread_data[:channel]}/p#{thread_data[:thread_ts].gsub('.', '')}"
  end
  
  def extract_participants(messages)
    participants = messages.map { |msg| msg[:user] }.uniq
    participants.map { |user_id| get_user_info(user_id) }.compact
  end
  
  def calculate_thread_duration(messages)
    return 0 if messages.length < 2
    
    first_message = messages.min_by { |msg| msg[:timestamp] }
    last_message = messages.max_by { |msg| msg[:timestamp] }
    
    (last_message[:timestamp] - first_message[:timestamp]) / 1.hour
  end
end
