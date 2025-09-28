class EmailIdleService
  def initialize
    @imap_config = {
      server: ENV['IMAP_SERVER'],
      port: ENV['IMAP_PORT']&.to_i || 993,
      username: ENV['IMAP_USERNAME'],
      password: ENV['IMAP_PASSWORD'],
      ssl: ENV['IMAP_SSL'] == 'true'
    }
    @running = false
    @idle_timeout = 30.minutes # Gmail drops connections after ~30 mins
  end

  def start_listening
    return { error: "IMAP configuration missing" } unless imap_configured?
    return { error: "Already running" } if @running

    @running = true
    Rails.logger.info "🚀 Starting IMAP IDLE listener for real-time email monitoring..."

    begin
      listen_for_emails
    rescue => e
      Rails.logger.error "IMAP IDLE listener error: #{e.message}"
      @running = false
      { error: "IMAP IDLE listener failed: #{e.message}" }
    end
  end

  def stop_listening
    @running = false
    Rails.logger.info "🛑 Stopping IMAP IDLE listener..."
  end

  def running?
    @running
  end

  private

  def imap_configured?
    @imap_config[:server].present? && 
    @imap_config[:username].present? && 
    @imap_config[:password].present?
  end

  def listen_for_emails
    Rails.logger.info "📧 Starting email monitoring (polling every 10 seconds)..."
    
    loop do
      break unless @running

      begin
        Rails.logger.info "📧 Checking for new emails..."
        
        Net::IMAP.new(@imap_config[:server], @imap_config[:port], @imap_config[:ssl]).tap do |imap|
          imap.login(@imap_config[:username], @imap_config[:password])
          imap.select('INBOX')
          
          # Process new emails
          process_new_emails(imap)
          
          imap.logout
          imap.disconnect
        end
        
        # Wait 10 seconds before next check
        Rails.logger.info "⏰ Waiting 10 seconds before next check..."
        sleep(10) if @running
        
      rescue Net::IMAP::Error => e
        Rails.logger.error "IMAP error: #{e.message}. Retrying in 30 seconds..."
        sleep(30) if @running
      rescue => e
        Rails.logger.error "Connection error: #{e.message}. Retrying in 30 seconds..."
        sleep(30) if @running
      end
    end
  end

  def process_new_emails(imap)
    # Get unread emails
    message_ids = imap.search(['UNSEEN'])
    
    return if message_ids.empty?
    
    Rails.logger.info "📋 Found #{message_ids.count} unread emails"
    
    message_ids.each do |message_id|
      begin
        email_data = fetch_email_data(imap, message_id)
        next unless email_data
        
        Rails.logger.info "📧 Processing email: #{email_data[:subject]}"
        Rails.logger.info "📧 From: #{email_data[:from]&.first&.dig(:email)}"
        
        # Check if it contains @roadie mention
        if contains_roadie_mention?(email_data)
          Rails.logger.info "🎯 Found email with @roadie mention: #{email_data[:subject]}"
          
          # Mark as read
          imap.store(message_id, '+FLAGS', [:Seen])
          
          # Process the email thread
          thread_context = extract_thread_context(email_data)
          
          # Queue for background processing
          EmailProcessingJob.perform_later(thread_context)
          
          Rails.logger.info "✅ Queued email for processing: #{email_data[:subject]}"
        else
          Rails.logger.info "📭 Email does not contain @roadie mention, skipping: #{email_data[:subject]}"
          # Mark as read anyway to avoid reprocessing
          imap.store(message_id, '+FLAGS', [:Seen])
        end
        
      rescue => e
        Rails.logger.error "Error processing email #{message_id}: #{e.message}"
      end
    end
  end

  def fetch_email_data(imap, message_id)
    envelope = imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
    body_data = imap.fetch(message_id, 'BODY[]')[0].attr['BODY[]']
    
    # Parse the email using the Mail gem
    mail = Mail.new(body_data)
    
    {
      message_id: envelope.message_id,
      subject: envelope.subject,
      from: parse_addresses(envelope.from),
      to: parse_addresses(envelope.to),
      cc: parse_addresses(envelope.cc),
      bcc: parse_addresses(envelope.bcc),
      date: envelope.date,
      body: extract_email_body(mail),
      thread_history: extract_thread_history(mail),
      attachments: extract_attachments(mail)
    }
  rescue => e
    Rails.logger.error "Error fetching email data: #{e.message}"
    nil
  end

  def parse_addresses(addresses)
    return [] unless addresses
    
    addresses.map do |addr|
      {
        name: addr.name,
        email: addr.mailbox + '@' + addr.host
      }
    end
  end

  def extract_email_body(mail)
    if mail.multipart?
      text_part = mail.text_part
      html_part = mail.html_part
      
      if text_part
        clean_text(text_part.body.decoded)
      elsif html_part
        clean_html(html_part.body.decoded)
      else
        clean_text(mail.body.decoded)
      end
    else
      if mail.content_type&.include?('text/html')
        clean_html(mail.body.decoded)
      else
        clean_text(mail.body.decoded)
      end
    end
  end

  def extract_thread_history(mail)
    body = extract_email_body(mail)
    
    separators = [
      /^On .+ wrote:$/m,
      /^From: .+$/m,
      /^Sent: .+$/m,
      /^To: .+$/m,
      /^Subject: .+$/m,
      /^-----Original Message-----/m,
      /^________________________________/m
    ]
    
    new_content = body
    separators.each do |separator|
      parts = new_content.split(separator)
      new_content = parts.first if parts.length > 1
    end
    
    quoted_content = body.gsub(new_content, '').strip
    
    {
      new_content: new_content.strip,
      quoted_content: quoted_content
    }
  end

  def extract_attachments(mail)
    return [] unless mail.multipart?
    
    mail.attachments.map do |attachment|
      {
        filename: attachment.filename,
        content_type: attachment.content_type,
        size: attachment.body.decoded.bytesize
      }
    end
  end

  def contains_roadie_mention?(email_data)
    body = email_data[:body].to_s.downcase
    subject = email_data[:subject].to_s.downcase
    
    body.include?('@roadie') || subject.include?('@roadie')
  end

  def extract_thread_context(email_data)
    {
      message_id: email_data[:message_id],
      subject: email_data[:subject],
      from: email_data[:from],
      to: email_data[:to],
      cc: email_data[:cc],
      bcc: email_data[:bcc],
      date: email_data[:date],
      thread_body: email_data[:body],
      thread_history: email_data[:thread_history],
      mentions: extract_mentions(email_data[:body]),
      attachments: email_data[:attachments]
    }
  end

  def extract_mentions(body)
    email_pattern = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
    emails = body.scan(email_pattern).uniq
    
    name_pattern = /(?:@|to|from|cc|bcc|hi|hello|dear)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i
    names = body.scan(name_pattern).flatten.uniq
    
    {
      emails: emails,
      names: names
    }
  end

  def clean_text(text)
    return '' unless text
    
    text.gsub(/\r\n/, "\n")
        .gsub(/\r/, "\n")
        .gsub(/\n{3,}/, "\n\n")
        .strip
  end

  def clean_html(html)
    return '' unless html
    
    text = html.gsub(/<br\s*\/?>/i, "\n")
               .gsub(/<\/p>/i, "\n\n")
               .gsub(/<[^>]+>/, '')
               .gsub(/&nbsp;/, ' ')
               .gsub(/&amp;/, '&')
               .gsub(/&lt;/, '<')
               .gsub(/&gt;/, '>')
               .gsub(/&quot;/, '"')
    
    clean_text(text)
  end
end
