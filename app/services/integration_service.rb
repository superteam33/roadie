class IntegrationService
  include HTTParty
  
  def initialize(integration_type, user)
    @integration_type = integration_type
    @user = user
    @tokens = user.integration_tokens
  end
  
  def process_command(command, context = {})
    case @integration_type
    when 'slack'
      process_slack_command(command, context)
    when 'github'
      process_github_command(command, context)
    when 'gmail'
      process_gmail_command(command, context)
    else
      raise "Unsupported integration type: #{@integration_type}"
    end
  end
  
  private
  
  def process_slack_command(command, context)
    # Parse Slack command and extract agent instructions
    agent_type = extract_agent_type(command)
    input_data = extract_input_data(command, context)
    
    if agent_type
      AiAgentService.new(agent_type).execute(input_data, @user.id)
    else
      { error: "Could not determine agent type from command: #{command}" }
    end
  end
  
  def process_github_command(command, context)
    # Process GitHub webhook or command
    case context[:event_type]
    when 'pull_request'
      handle_pull_request_event(context[:payload])
    when 'issue'
      handle_issue_event(context[:payload])
    else
      { error: "Unsupported GitHub event type: #{context[:event_type]}" }
    end
  end
  
  def process_gmail_command(command, context)
    # Process Gmail command via email parsing
    agent_type = extract_agent_type_from_email(command)
    input_data = extract_input_data_from_email(command, context)
    
    if agent_type
      AiAgentService.new(agent_type).execute(input_data, @user.id)
    else
      { error: "Could not determine agent type from email: #{command}" }
    end
  end
  
  def extract_agent_type(command)
    # Extract agent type from command text
    case command.downcase
    when /prd|product requirements|requirements doc/
      'prd_generator'
    when /break down|tasks|epic/
      'task_breaker'
    when /roadmap|timeline|schedule/
      'roadmap_creator'
    when /status|update|progress/
      'status_updater'
    else
      nil
    end
  end
  
  def extract_input_data(command, context)
    {
      command: command,
      context: context,
      user_id: @user.id,
      timestamp: Time.current
    }
  end
  
  def handle_pull_request_event(payload)
    # Handle GitHub PR events
    pr_data = {
      action: payload['action'],
      title: payload['pull_request']['title'],
      body: payload['pull_request']['body'],
      author: payload['pull_request']['user']['login'],
      url: payload['pull_request']['html_url']
    }
    
    # Determine if this needs agent processing
    if pr_data[:title].downcase.include?('@roadie') || pr_data[:body].downcase.include?('@roadie')
      AiAgentService.new('status_updater').execute(pr_data, @user.id)
    else
      { message: 'PR processed, no agent action needed' }
    end
  end
  
  def handle_issue_event(payload)
    # Handle GitHub issue events
    issue_data = {
      action: payload['action'],
      title: payload['issue']['title'],
      body: payload['issue']['body'],
      author: payload['issue']['user']['login'],
      url: payload['issue']['html_url']
    }
    
    # Check if issue mentions @roadie
    if issue_data[:title].downcase.include?('@roadie') || issue_data[:body].downcase.include?('@roadie')
      AiAgentService.new('task_breaker').execute(issue_data, @user.id)
    else
      { message: 'Issue processed, no agent action needed' }
    end
  end
  
  def extract_agent_type_from_email(email_content)
    # Extract agent type from email content
    case email_content.downcase
    when /prd|product requirements|requirements doc/
      'prd_generator'
    when /break down|tasks|epic/
      'task_breaker'
    when /roadmap|timeline|schedule/
      'roadmap_creator'
    when /status|update|progress/
      'status_updater'
    else
      nil
    end
  end
  
  def extract_input_data_from_email(email_content, context)
    {
      email_content: email_content,
      context: context,
      user_id: @user.id,
      timestamp: Time.current
    }
  end
end
