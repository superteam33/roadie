class AiServiceFactory
  def self.create_service
    case ENV['AI_SERVICE_PROVIDER']&.downcase
    when 'groq'
      GroqService.new
    when 'openai'
      OpenAIService.new
    else
      # Default to OpenAI if no environment variable is set
      Rails.logger.warn "AI_SERVICE_PROVIDER not set, defaulting to OpenAI"
      OpenAIService.new
    end
  end
  
  def self.available_services
    %w[openai groq]
  end
  
  def self.current_service
    ENV['AI_SERVICE_PROVIDER']&.downcase || 'openai'
  end
end
