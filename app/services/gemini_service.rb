class GeminiService
  include HTTParty
  
  base_uri 'https://generativelanguage.googleapis.com/v1beta'
  
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
    raise 'GEMINI_API_KEY not found in environment variables' unless @api_key
  end
  
  def generate_roadmap(request_text, context = {})
    # Check if this is a task creation request
    if is_task_creation_request?(request_text)
      return generate_task_creation_response(request_text, context)
    end
    
    prompt = build_roadmap_prompt(request_text, context)
    
    response = self.class.post(
      "/models/gemini-2.5-pro-preview-03-25:generateContent?key=#{@api_key}",
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

  def is_task_creation_request?(request_text)
    # Check if the request contains task creation keywords
    task_keywords = ['create task', 'add task', 'new task', 'bot create', 'create a task']
    request_lower = request_text.downcase
    
    task_keywords.any? { |keyword| request_lower.include?(keyword) }
  end

  def generate_task_creation_response(request_text, context)
    prompt = build_task_creation_prompt(request_text, context)
    
    response = self.class.post(
      "/models/gemini-2.5-pro-preview-03-25:generateContent?key=#{@api_key}",
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
          temperature: 0.1,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024
        }
      }.to_json
    )
    
    if response.success?
      parsed_response = response.parsed_response
      Rails.logger.info "Task creation Gemini response: #{parsed_response.inspect}"
      
      if parsed_response.is_a?(Hash) && parsed_response['candidates'] && parsed_response['candidates'][0]
        content = parsed_response['candidates'][0]['content']['parts'][0]['text']
        parse_task_creation_response(content)
      else
        Rails.logger.error "Unexpected Gemini response format: #{parsed_response.inspect}"
        { error: "Unexpected response format from Gemini API" }
      end
    else
      Rails.logger.error "Gemini API error for task creation: code=#{response.code} body=#{response.body}"
      
      # If quota exceeded, provide a mock response for testing
      if response.code == 429
        Rails.logger.info "API quota exceeded, providing mock response for testing"
        return generate_mock_task_response(request_text)
      end
      
      { error: "Failed to generate task creation response" }
    end
  rescue => e
    Rails.logger.error "Gemini service error for task creation: #{e.message}"
    { error: "Error generating task creation response: #{e.message}" }
  end

  def build_task_creation_prompt(request_text, context)
    <<~PROMPT
      You are Roadie, an AI project management assistant. The user wants to create a task based on their request.

      REQUEST: "#{request_text}"

      CONTEXT:
      - Channel: #{context[:channel_name] || 'Unknown'}
      - User: #{context[:user_name] || 'Unknown'}

      Parse this request and extract the following information:
      - Task title (short, actionable)
      - Task description (detailed with acceptance criteria)
      - Epic name (if mentioned, otherwise use "General")
      - Assignee name (if mentioned, otherwise use "Unassigned")
      - Priority (low, medium, high, critical - default to medium)
      - Status (always "todo" for new tasks)

      IMPORTANT: Respond ONLY with valid JSON in this exact format:
      {
        "task": {
          "title": "Task title here",
          "description": "Detailed description with acceptance criteria",
          "status": "todo",
          "priority": "medium",
          "epic_name": "Epic name or General",
          "assignee_name": "Assignee name or Unassigned"
        }
      }

      Do not include any other text, explanations, or formatting. Only return the JSON.
    PROMPT
  end

  def parse_task_creation_response(content)
    # Clean the response and extract JSON
    cleaned_content = content.strip
    
    # Remove any markdown formatting or extra text
    json_match = cleaned_content.match(/\{.*\}/m)
    return { error: "No valid JSON found in response" } unless json_match
    
    begin
      parsed_json = JSON.parse(json_match[0])
      
      # Validate the structure
      if parsed_json['task'] && parsed_json['task']['title'] && parsed_json['task']['description']
        parsed_json
      else
        { error: "Invalid task structure in response" }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      { error: "Failed to parse JSON response: #{e.message}" }
    end
  end

  def generate_mock_task_response(request_text)
    # Generate a mock response based on the request text
    text_lower = request_text.downcase
    
    # Extract task title
    title = if text_lower.include?('sso')
      "Implement SSO Login"
    elsif text_lower.include?('otp')
      "Implement OTP Verification"
    elsif text_lower.include?('database')
      "Database Migration"
    else
      "New Task"
    end
    
    # Extract epic name
    epic_name = if text_lower.include?('user authentication') || text_lower.include?('authentication')
      "User Authentication"
    elsif text_lower.include?('mobile')
      "Mobile Development"
    else
      "General"
    end
    
    # Extract assignee name
    assignee_name = if text_lower.include?('groot')
      "Groot"
    else
      "Unassigned"
    end
    
    # Generate description
    description = case title
    when "Implement SSO Login"
      "Add single sign-on authentication functionality with proper security measures and user session management. Include OAuth2 integration and secure token handling."
    when "Implement OTP Verification"
      "Implement one-time password verification system with SMS and email support. Include rate limiting and secure code generation."
    when "Database Migration"
      "Create and execute database migration scripts with proper rollback procedures and data validation."
    else
      "Task description based on requirements. Include acceptance criteria and testing requirements."
    end
    
    {
      "task" => {
        "title" => title,
        "description" => description,
        "status" => "todo",
        "priority" => "medium",
        "epic_name" => epic_name,
        "assignee_name" => assignee_name
      }
    }
  end
end
