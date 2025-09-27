class OpenAIService
  include HTTParty
  
  base_uri 'https://api.openai.com/v1'
  
  def initialize
    @api_key = ENV['OPEN_AI_API_KEY']
    raise 'OPEN_AI_API_KEY not found in environment variables' unless @api_key
  end
  
  def generate_roadmap(request_text, context = {})
    # Always generate task creation response in JSON format
    generate_task_creation_response(request_text, context)
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
      '/chat/completions',
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@api_key}"
      },
      body: {
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.1,
        max_tokens: 1024
      }.to_json
    )
    
    if response.success?
      parsed_response = response.parsed_response
      Rails.logger.info "OpenAI task creation response: #{parsed_response.inspect}"
      
      if parsed_response.is_a?(Hash) && parsed_response['choices'] && parsed_response['choices'][0]
        content = parsed_response['choices'][0]['message']['content']
        parse_task_creation_response(content)
      else
        Rails.logger.error "Unexpected OpenAI response format: #{parsed_response.inspect}"
        { error: "Unexpected response format from OpenAI API" }
      end
    else
      Rails.logger.error "OpenAI API error for task creation: code=#{response.code} body=#{response.body}"
      { error: "Failed to generate task creation response" }
    end
  rescue => e
    Rails.logger.error "OpenAI service error for task creation: #{e.message}"
    { error: "Error generating task creation response: #{e.message}" }
  end

  def build_task_creation_prompt(request_text, context)
    <<~PROMPT
      You are Roadie, an AI project management assistant. Based on the user's request, create tasks that can be added to a project management board.

      REQUEST: "#{request_text}"

      CONTEXT:
      - Channel: #{context[:channel_name] || 'Unknown'}
      - User: #{context[:user_name] || 'Unknown'}
      - Thread participants: #{context[:participants]&.map { |p| p[:name] }&.join(', ') || 'Unknown'}

      Analyze the request and create 3-6 actionable tasks. For each task:
      - Extract task title (short, actionable)
      - Create detailed description with acceptance criteria
      - Identify epic name (if mentioned in context, otherwise leave blank)
      - Identify assignee name (if mentioned in context, otherwise leave blank)
      - Set priority (low, medium, high, critical - default to medium)
      - Set status (always "todo" for new tasks)
      - Set due_date (if mentioned, otherwise null)

      IMPORTANT: Respond ONLY with valid JSON in this exact format:
      [
        {
          "title": "Task title here",
          "description": "Detailed description with acceptance criteria",
          "status": "todo",
          "priority": "medium",
          "epic_name": "Epic name or blank if not mentioned",
          "assignee_name": "Assignee name or blank if not mentioned",
          "due_date": "2025-10-20T15:30:00Z or null"
        }
      ]

      Do not include any other text, explanations, or formatting. Only return the JSON array.
    PROMPT
  end

  def parse_task_creation_response(content)
    # Clean the response and extract JSON
    cleaned_content = content.strip
    
    # Remove any markdown formatting or extra text
    json_match = cleaned_content.match(/\[.*\]/m)
    return { error: "No valid JSON array found in response" } unless json_match
    
    begin
      parsed_json = JSON.parse(json_match[0])
      
      # Validate the structure - should be an array of tasks
      if parsed_json.is_a?(Array) && parsed_json.all? { |task| task['title'] && task['description'] }
        { tasks: parsed_json }
      else
        { error: "Invalid task array structure in response" }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      { error: "Failed to parse JSON response: #{e.message}" }
    end
  end
end
