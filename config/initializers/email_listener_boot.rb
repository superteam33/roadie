# Auto-start email listener when Rails application boots
Rails.application.configure do
  # Only start in production and development environments
  # Skip in test environment to avoid interference with tests
  if Rails.env.production? || Rails.env.development?
    config.after_initialize do
      # Start the email listener after Rails has fully initialized
      Rails.logger.info "🚀 Auto-starting email listener..."
      
      # Use a small delay to ensure all services are ready
      Thread.new do
        sleep(5) # Wait 5 seconds for Rails to fully boot
        
        begin
          # Check if IMAP configuration is available
          if ENV['IMAP_SERVER'].present? && 
             ENV['IMAP_USERNAME'].present? && 
             ENV['IMAP_PASSWORD'].present?
            
            Rails.logger.info "📧 IMAP configuration found. Starting email listener..."
            
            # Start the IDLE listener directly
            email_idle_service = EmailIdleService.new
            email_idle_service.start_listening
            
            Rails.logger.info "✅ Email listener started successfully!"
            Rails.logger.info "🎯 Monitoring for emails with @roadie mentions..."
            Rails.logger.info "📧 Real-time IMAP IDLE listener is active"
            
          else
            Rails.logger.warn "⚠️  IMAP configuration missing. Email listener not started."
            Rails.logger.warn "   Please set IMAP_SERVER, IMAP_USERNAME, and IMAP_PASSWORD in your .env file"
          end
        rescue => e
          Rails.logger.error "❌ Failed to start email listener: #{e.message}"
        end
      end
    end
  else
    Rails.logger.info "📧 Email listener auto-start disabled in #{Rails.env} environment"
  end
end
