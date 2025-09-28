class EmailContextService
  include HTTParty
  
  base_uri 'https://api.openai.com/v1'
  
  def initialize
    @api_key = ENV['OPEN_AI_API_KEY']
    raise 'OPEN_AI_API_KEY not found in environment variables' unless @api_key
  end

  def interpret_email_context(email_context)
    prompt = build_email_context_prompt(email_context)
    
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
            role: 'system',
            content: system_prompt
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.1,
        max_tokens: 2048
      }.to_json
    )
    
    if response.success?
      parsed_response = response.parsed_response
      Rails.logger.info "OpenAI email context response: #{parsed_response.inspect}"
      
      if parsed_response.is_a?(Hash) && parsed_response['choices'] && parsed_response['choices'][0]
        content = parsed_response['choices'][0]['message']['content']
        parse_email_context_response(content)
      else
        Rails.logger.error "Unexpected OpenAI response format: #{parsed_response.inspect}"
        { error: "Unexpected response format from OpenAI API" }
      end
    else
      Rails.logger.error "OpenAI API error for email context: code=#{response.code} body=#{response.body}"
      { error: "Failed to interpret email context" }
    end
  rescue => e
    Rails.logger.error "OpenAI service error for email context: #{e.message}"
    { error: "Error interpreting email context: #{e.message}" }
  end

  private

  def system_prompt
    <<~PROMPT
      You are Roadie, an AI project management assistant that specializes in interpreting email threads and converting them into actionable tasks.

      Your role is to:
      1. Analyze email thread context to understand the conversation flow
      2. Identify action items, requests, and tasks mentioned in the thread
      3. Extract relevant information like deadlines, assignees, and priorities
      4. Create structured task data that can be imported into a project management system

      Always respond with valid JSON in the specified format. Be thorough in your analysis but concise in your output.
    PROMPT
  end

  def build_email_context_prompt(email_context)
    <<~PROMPT
      Analyze the following email thread and extract actionable tasks. The email contains a mention of @roadie, indicating that tasks should be created from this conversation.

      EMAIL THREAD CONTEXT:
      
      Subject: #{email_context[:subject]}
      From: #{format_participants(email_context[:from])}
      To: #{format_participants(email_context[:to])}
      CC: #{format_participants(email_context[:cc])}
      Date: #{email_context[:date]}
      
      THREAD CONTENT:
      #{email_context[:thread_body]}
      
      THREAD HISTORY:
      #{email_context[:thread_history][:quoted_content] if email_context[:thread_history]}
      
      MENTIONS FOUND:
      - Emails: #{email_context[:mentions][:emails].join(', ')}
      - Names: #{email_context[:mentions][:names].join(', ')}

      Based on this email thread, create 2-6 actionable tasks. For each task:
      - Extract a clear, actionable title
      - Create a detailed description with context from the email
      - Identify the most appropriate assignee based on mentions and context
      - Set priority based on urgency indicators in the email
      - Extract due date if mentioned
      - Identify epic/category if context suggests one

      IMPORTANT: Respond ONLY with valid JSON in this exact format:
      {
        "summary": "Brief summary of the email thread and what tasks were created",
        "project_context": "Suggested project or epic name based on email content",
        "tasks": [
          {
            "title": "Clear, actionable task title",
            "description": "Detailed description with acceptance criteria and context from email",
            "status": "todo",
            "priority": "low|medium|high|critical",
            "assignee_email": "email@example.com or null if not determinable",
            "assignee_name": "Full name or null if not determinable",
            "due_date": "2025-10-20T15:30:00Z or null",
            "epic_name": "Epic name or null if not mentioned",
            "context_notes": "Additional context from the email thread"
          }
        ]
      }

      Do not include any other text, explanations, or formatting. Only return the JSON object.
    PROMPT
  end

  def format_participants(participants)
    return 'None' unless participants&.any?
    
    participants.map do |participant|
      if participant[:name].present?
        "#{participant[:name]} <#{participant[:email]}>"
      else
        participant[:email]
      end
    end.join(', ')
  end

  def parse_email_context_response(content)
    # Clean the response and extract JSON
    cleaned_content = content.strip
    
    # Remove any markdown formatting or extra text
    json_match = cleaned_content.match(/\{.*\}/m)
    return { error: "No valid JSON object found in response" } unless json_match
    
    begin
      parsed_json = JSON.parse(json_match[0])
      
      # Validate the structure
      if parsed_json.is_a?(Hash) && 
         parsed_json['tasks'].is_a?(Array) && 
         parsed_json['tasks'].all? { |task| task['title'] && task['description'] }
        parsed_json
      else
        { error: "Invalid task structure in response" }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      { error: "Failed to parse JSON response: #{e.message}" }
    end
  end
end
