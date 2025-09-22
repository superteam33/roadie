# Slack configuration
Slack.configure do |config|
  config.token = ENV['SLACK_BOT_TOKEN']
end

# Configure Slack client
Slack::Web::Client.configure do |config|
  config.token = ENV['SLACK_BOT_TOKEN']
  config.logger = Rails.logger
end
