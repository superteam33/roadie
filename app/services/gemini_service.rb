class GeminiService
  include HTTParty
  
  base_uri 'https://generativelanguage.googleapis.com/v1beta'
  
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
    raise 'GEMINI_API_KEY not found in environment variables' unless @api_key
  end
  
  def generate_roadmap(request_text, context = {})
    prompt = build_roadmap_prompt(request_text, context)
    
    response = self.class.post(
      "/models/gemini-1.5-flash:generateContent?key=#{@api_key}",
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        contents: [{
          parts: [{
            text: prompt
          }]
        }],
        generationConfig: {
          temperature: 0.3,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048
        }
      }.to_json
    )
    
    if response.success?
      parsed_response = response.parsed_response
      Rails.logger.info "Gemini response: #{parsed_response.inspect}"
      
      if parsed_response.is_a?(Hash) && parsed_response['candidates'] && parsed_response['candidates'][0]
        content = parsed_response['candidates'][0]['content']['parts'][0]['text']
        format_roadmap_response(content)
      else
        Rails.logger.error "Unexpected Gemini response format: #{parsed_response.inspect}"
        { error: "Unexpected response format from Gemini API" }
      end
    else
      # Try to parse structured error from Google API
      begin
        body = response.parsed_response.is_a?(Hash) ? response.parsed_response : JSON.parse(response.body)
      rescue JSON::ParserError
        body = { 'error' => { 'message' => response.body } }
      end

      error_reason = body.dig('error', 'status') || body.dig('error', 'message') ||
                     (body.is_a?(Hash) && body['error'] && body['error'].is_a?(Hash) ? body['error']['message'] : nil)
      details = body.dig('error', 'details') || body['details']
      if details.is_a?(Array)
        api_key_issue = details.find { |d| d['@type'].to_s.include?('ErrorInfo') && d['reason'] == 'API_KEY_INVALID' }
      end

      human_message = if api_key_issue
        "Gemini API key is invalid. Update GEMINI_API_KEY and restart the server."
      elsif response.code.to_i == 403
        "Gemini API access forbidden. Check billing/quotas and API enablement."
      else
        "Failed to generate roadmap: #{response.code}#{" - #{error_reason}" if error_reason}"
      end

      Rails.logger.error "Gemini API error: code=#{response.code} body=#{response.body}"
      { error: human_message }
    end
  rescue => e
    Rails.logger.error "Gemini service error: #{e.message}"
    { error: "Error generating roadmap: #{e.message}" }
  end
  
  private
  
  def build_roadmap_prompt(request_text, context)
    <<~PROMPT
      You are Roadie, an expert AI project management assistant. Based on the following request, generate a concise **task breakdown** that can map directly into Jira tickets or GitHub issues.

      REQUEST: "#{request_text}"
  
      CONTEXT:
      - Channel: #{context[:channel_name] || 'Unknown'}
      - User: #{context[:user_name] || 'Unknown'}
      - Thread participants: #{context[:participants]&.map { |p| p[:name] }&.join(', ') || 'Unknown'}
  
      🔹 Please output a **list of 4–6 independent subtasks** only.  
      🔹 Each subtask should include:
        - **Title** (short, actionable, e.g. "Implement OTP verification API")  
        - **Description** (1–2 lines with details / acceptance criteria)  
  
      ⚡ Formatting Rules (Slack-friendly):
      - Use a numbered list for tasks (1, 2, 3 …)  
      - Keep each task **crisp and execution-ready** (no fluff, no long paragraphs)  
      - Avoid project overviews, risks, success metrics, or timelines — just subtasks
      - Must add acceptance criteria for each task.
  
      Example format:
  
      1. **Design DB Schema for OTP**  
         Add `otp_code` and `expiry` fields in `users` table. Ensure expiry logic is enforced.  
  
      2. **Implement OTP API Endpoint**  
         Create `/auth/otp` to send and verify OTP codes with proper error handling.  

    PROMPT
  end  
  
  def format_roadmap_response(content)
    # Clean up the response and ensure proper formatting
    formatted_content = content.to_s.strip
    
    # Add some basic formatting if not present
    unless formatted_content.include?('**') || formatted_content.include?('*')
      formatted_content = formatted_content.gsub(/^(\d+\.\s)/, '**\1**')
      formatted_content = formatted_content.gsub(/^([A-Z][^:]+:)/, '**\1**')
    end
    
    # Add a header
    header = "🗺️ **PRODUCT ROADMAP GENERATED**\n\n"
    
    header + formatted_content
  end
end
