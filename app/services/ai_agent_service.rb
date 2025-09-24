class AiAgentService
  include HTTParty
  
  def initialize(agent_type)
    @agent_type = agent_type
    @gemini_api_key = ENV['GEMINI_API_KEY']
    @openai_api_key = ENV['OPENAI_API_KEY'] # Keep as fallback
    @anthropic_api_key = ENV['ANTHROPIC_API_KEY'] # Keep as fallback
  end
  
  def execute(input_data, user_id = nil)
    execution = create_execution(input_data, user_id)
    
    begin
      execution.update!(status: 'running')
      start_time = Time.current
      
      result = case @agent_type
      when 'prd_generator'
        generate_prd(input_data)
      when 'task_breaker'
        break_down_tasks(input_data)
      when 'roadmap_creator'
        create_roadmap(input_data)
      when 'status_updater'
        update_statuses(input_data)
      else
        raise "Unknown agent type: #{@agent_type}"
      end
      
      execution_time = ((Time.current - start_time) * 1000).to_i
      execution.update!(
        status: 'completed',
        output: result.to_json,
        execution_time: execution_time
      )
      
      result
    rescue => e
      execution.update!(
        status: 'failed',
        output: { error: e.message }.to_json
      )
      raise e
    end
  end
  
  private
  
  def create_execution(input_data, user_id)
    agent = Agent.find_by(agent_type: @agent_type, status: 'active')
    raise "No active agent found for type: #{@agent_type}" unless agent
    
    AgentExecution.create!(
      agent: agent,
      user_id: user_id,
      status: 'pending',
      input: input_data.to_json
    )
  end
  
  def generate_prd(input_data)
    prompt = build_prd_prompt(input_data)
    call_gemini(prompt)
  end
  
  def break_down_tasks(input_data)
    prompt = build_task_breakdown_prompt(input_data)
    call_gemini(prompt)
  end
  
  def create_roadmap(input_data)
    # Use the dedicated Gemini service for roadmap generation
    gemini_service = GeminiService.new
    result = gemini_service.generate_roadmap(
      input_data[:command] || input_data[:project_goals] || 'No goals specified',
      {
        channel_name: input_data[:context]&.dig(:channel_name),
        user_name: input_data[:context]&.dig(:user_name),
        participants: input_data[:context]&.dig(:participants)
      }
    )
    Rails.logger.info "AiAgentService.create_roadmap returning: #{result.inspect}"
    result
  end
  
  def update_statuses(input_data)
    prompt = build_status_update_prompt(input_data)
    call_gemini(prompt)
  end
  
  def call_gemini(prompt)
    # Try Gemini first
    if @gemini_api_key.present?
      call_gemini_api(prompt)
    elsif @openai_api_key.present?
      call_openai(prompt)
    else
      raise "No AI API key configured. Please set GEMINI_API_KEY or OPENAI_API_KEY"
    end
  end
  
  def call_gemini_api(prompt)
    response = HTTParty.post(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{@gemini_api_key}",
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
          temperature: 0.7,
          maxOutputTokens: 2000,
          topP: 0.8,
          topK: 10
        }
      }.to_json
    )
    
    if response.success?
      result = JSON.parse(response.body)
      if result['candidates'] && result['candidates'][0] && result['candidates'][0]['content']
        result['candidates'][0]['content']['parts'][0]['text']
      else
        raise "Gemini API error: #{result}"
      end
    else
      raise "Gemini API error: #{response.body}"
    end
  end
  
  def call_openai(prompt)
    response = HTTParty.post(
      'https://api.openai.com/v1/chat/completions',
      headers: {
        'Authorization' => "Bearer #{@openai_api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'gpt-4',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
        max_tokens: 2000
      }.to_json
    )
    
    if response.success?
      JSON.parse(response.body)['choices'][0]['message']['content']
    else
      raise "OpenAI API error: #{response.body}"
    end
  end
  
  def build_prd_prompt(input_data)
    project_name = input_data[:project_name] || 'Unknown Project'
    requirements = input_data[:requirements] || 'No specific requirements provided'
    
    <<~PROMPT
      Generate a comprehensive Product Requirements Document (PRD) for the following project:
      
      Project Name: #{project_name}
      Requirements: #{requirements}
      
      Please structure the PRD with the following sections:
      1. Executive Summary
      2. Problem Statement
      3. Goals and Objectives
      4. Target Audience
      5. User Stories
      6. Functional Requirements
      7. Non-Functional Requirements
      8. Success Metrics
      9. Timeline and Milestones
      10. Risks and Assumptions
      
      Make the PRD detailed, actionable, and professional.
    PROMPT
  end
  
  def build_task_breakdown_prompt(input_data)
    epic_description = input_data[:epic_description] || 'No description provided'
    project_context = input_data[:project_context] || 'No context provided'
    
    <<~PROMPT
      Break down the following epic into actionable tasks:
      
      Epic Description: #{epic_description}
      Project Context: #{project_context}
      
      Please provide:
      1. A list of 5-10 specific, actionable tasks
      2. For each task, include:
         - Title
         - Description
         - Estimated effort (in story points or hours)
         - Priority level (low, medium, high, critical)
         - Dependencies (if any)
         - Acceptance criteria
      
      Format the response as a structured JSON object.
    PROMPT
  end
  
  def build_roadmap_prompt(input_data)
    project_goals = input_data[:project_goals] || 'No goals specified'
    timeline = input_data[:timeline] || 'No timeline specified'
    
    <<~PROMPT
      Create a detailed project roadmap based on the following information:
      
      Project Goals: #{project_goals}
      Timeline: #{timeline}
      
      Please provide:
      1. Project phases with clear milestones
      2. Timeline for each phase
      3. Key deliverables
      4. Dependencies between phases
      5. Risk mitigation strategies
      6. Resource requirements
      
      Format as a structured roadmap with clear phases and timelines.
    PROMPT
  end
  
  def build_status_update_prompt(input_data)
    current_status = input_data[:current_status] || 'Unknown'
    project_context = input_data[:project_context] || 'No context provided'
    
    <<~PROMPT
      Analyze the current project status and provide recommendations for updates:
      
      Current Status: #{current_status}
      Project Context: #{project_context}
      
      Please provide:
      1. Status assessment
      2. Recommended status updates
      3. Next steps
      4. Risk alerts
      5. Resource adjustments needed
      
      Be specific and actionable in your recommendations.
    PROMPT
  end
end
