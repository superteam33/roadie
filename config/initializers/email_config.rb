# Email listener configuration
Rails.application.configure do
  config.email_processing = {
    enabled: ENV['EMAIL_PROCESSING_ENABLED'] == 'true',
    check_interval: ENV['EMAIL_CHECK_INTERVAL']&.to_i || 10, # seconds
    max_emails_per_check: ENV['EMAIL_MAX_PER_CHECK']&.to_i || 50,
    roadie_mention_pattern: /@roadie/i
  }
end
