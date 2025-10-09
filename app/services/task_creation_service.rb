class TaskCreationService
  def initialize(user)
    @user = user
  end

  def create_task_from_slack_request(request_text, context = {})
    # Parse the request to extract task details using OpenAI
    response_data = parse_task_request(request_text, context)
    
    return { error: "Could not parse task request" } unless response_data
    return { error: response_data[:error] } if response_data[:error]

    # Get the project (use first project for now)
    project = find_project(nil)
    return { error: "No project found" } unless project

    # Process each task in the response
    created_tasks = []
    errors = []

    response_data[:tasks].each do |task_data|
      begin
        # Find epic and assignee for this task
        epic = find_epic(task_data['epic_name'], project) if task_data['epic_name'].present?
        # If no epic found, use the first epic from the project
        epic ||= project.epics.first
        
        assignee = find_assignee(task_data['assignee_name']) if task_data['assignee_name'].present?

        # Create the task
        task = create_task_from_data(task_data, project, epic, assignee)
        
        if task.persisted?
          created_tasks << format_task_response(task)
        else
          errors << "Failed to create task '#{task_data['title']}': #{task.errors.full_messages.join(', ')}"
        end
      rescue => e
        errors << "Error creating task '#{task_data['title']}': #{e.message}"
      end
    end

    if created_tasks.any?
      {
        success: true,
        tasks: created_tasks,
        errors: errors
      }
    else
      {
        error: "Failed to create any tasks. Errors: #{errors.join('; ')}"
      }
    end
  end

  def create_tasks_from_email_context(email_context_data, context = {})
    # Parse the email context to extract task details using OpenAI
    response_data = parse_email_context(email_context_data)
    
    return { error: "Could not parse email context" } unless response_data
    return { error: response_data[:error] } if response_data[:error]

    # Get or create project based on email context
    project = find_or_create_project_from_email(response_data, context)
    return { error: "Could not find or create project" } unless project

    # Process each task in the response
    created_tasks = []
    errors = []

    response_data['tasks'].each do |task_data|
      begin
        # Find epic and assignee for this task
        epic = find_or_create_epic(task_data['epic_name'], project) if task_data['epic_name'].present?
        assignee = find_assignee_by_email_or_name(task_data['assignee_email'], task_data['assignee_name'])

        # Create the task with email context
        task = create_task_from_email_data(task_data, project, epic, assignee, email_context_data)
        
        if task.persisted?
          created_tasks << format_task_response(task)
        else
          errors << "Failed to create task '#{task_data['title']}': #{task.errors.full_messages.join(', ')}"
        end
      rescue => e
        errors << "Error creating task '#{task_data['title']}': #{e.message}"
      end
    end

    if created_tasks.any?
      {
        success: true,
        tasks: created_tasks,
        errors: errors,
        summary: response_data['summary'],
        project_context: response_data['project_context']
      }
    else
      {
        error: "Failed to create any tasks. Errors: #{errors.join('; ')}"
      }
    end
  end

  private

  def parse_task_request(request_text, context)
    # Use AI service factory to parse the task request
    ai_service = AiServiceFactory.create_service
    parsed_data = ai_service.generate_roadmap(request_text, context)
    
    return nil unless parsed_data && parsed_data.is_a?(Hash)
    
    # Return the parsed data directly (now contains tasks array)
    parsed_data
  end

  def find_project(project_name)
    return @user.owned_projects.first if project_name.blank?
    
    @user.owned_projects.find_by("LOWER(name) LIKE ?", "%#{project_name.downcase}%")
  end

  def find_epic(epic_name, project)
    return nil if epic_name.blank?
    
    project.epics.find_by("LOWER(name) LIKE ?", "%#{epic_name.downcase}%")
  end

  def find_assignee(assignee_name)
    return nil if assignee_name.blank?
    
    # Try to find by first name, last name, or full name
    User.where("LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(CONCAT(first_name, ' ', last_name)) LIKE ?", 
               "%#{assignee_name.downcase}%", 
               "%#{assignee_name.downcase}%", 
               "%#{assignee_name.downcase}%").first
  end

  def create_task_from_data(task_data, project, epic, assignee)
    # Parse due_date if provided
    due_date = nil
    if task_data['due_date'].present? && task_data['due_date'] != 'null'
      begin
        due_date = Time.parse(task_data['due_date'])
      rescue
        due_date = nil
      end
    end

    task = Task.create!(
      title: task_data['title'],
      description: task_data['description'],
      status: task_data['status'] || 'todo',
      priority: task_data['priority'] || 'medium',
      project: project,
      epic: epic,
      assignee: assignee,
      due_date: due_date
    )

    # Automatically create GitHub issue if project is linked to GitHub
    if task.persisted? && project.github_project_mapping.present?
      begin
        github_service = GithubService.new(@user)
        github_service.create_task(task)
        Rails.logger.info "✅ Task #{task.id} automatically created in GitHub"
      rescue => e
        Rails.logger.error "❌ Failed to create GitHub issue for task #{task.id}: #{e.message}"
        # Don't fail the task creation if GitHub fails
      end
    end

    task
  end

  def create_task(task_data, project, epic, assignee)
    Task.create!(
      title: task_data[:title],
      description: task_data[:description],
      status: task_data[:status] || 'todo',
      priority: task_data[:priority] || 'medium',
      project: project,
      epic: epic,
      assignee: assignee,
      due_date: task_data[:due_date]
    )
  end

  def format_task_response(task)
    {
      uuid: task.uuid,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      epic_uuid: task.epic&.uuid,
      assignee_uuid: task.assignee&.uuid,
      project_uuid: task.project.uuid,
      due_date: task.due_date&.iso8601
    }
  end

  def parse_email_context(email_context_data)
    # Use EmailContextService to parse the email context
    email_context_service = EmailContextService.new
    email_context_service.interpret_email_context(email_context_data)
  end

  def find_or_create_project_from_email(response_data, context)
    # Try to find existing project based on project_context
    project_name = response_data['project_context']
    
    if project_name.present?
      project = @user.owned_projects.find_by("LOWER(name) LIKE ?", "%#{project_name.downcase}%")
      return project if project
    end
    
    # Create new project if none found
    project_name ||= "Email Tasks - #{Date.current.strftime('%Y-%m-%d')}"
    
    @user.owned_projects.create!(
      name: project_name,
      status: 'active'
    )
  end

  def find_or_create_epic(epic_name, project)
    return nil if epic_name.blank?
    
    # Try to find existing epic
    epic = project.epics.find_by("LOWER(name) LIKE ?", "%#{epic_name.downcase}%")
    return epic if epic
    
    # Create new epic if none found
    project.epics.create!(
      name: epic_name,
      status: 'backlog',
      priority: 'medium'
    )
  end

  def find_assignee_by_email_or_name(email, name)
    # First try to find by email
    if email.present?
      user = User.find_by(email: email.downcase)
      return user if user
    end
    
    # Then try to find by name
    if name.present?
      return find_assignee(name)
    end
    
    nil
  end

  def create_task_from_email_data(task_data, project, epic, assignee, email_context)
    # Parse due_date if provided
    due_date = nil
    if task_data['due_date'].present? && task_data['due_date'] != 'null'
      begin
        due_date = Time.parse(task_data['due_date'])
      rescue
        due_date = nil
      end
    end

    # Enhance description with email context
    enhanced_description = build_enhanced_description(task_data, email_context)

    task = Task.create!(
      title: task_data['title'],
      description: enhanced_description,
      status: task_data['status'] || 'todo',
      priority: task_data['priority'] || 'medium',
      project: project,
      epic: epic,
      assignee: assignee,
      due_date: due_date
    )

    # Automatically create GitHub issue if project is linked to GitHub
    if task.persisted? && project.github_project_mapping.present?
      begin
        github_service = GithubService.new(@user)
        github_service.create_task(task)
        Rails.logger.info "✅ Task #{task.id} automatically created in GitHub from email"
      rescue => e
        Rails.logger.error "❌ Failed to create GitHub issue for task #{task.id}: #{e.message}"
        # Don't fail the task creation if GitHub fails
      end
    end

    task
  end

  def build_enhanced_description(task_data, email_context)
    base_description = task_data['description'] || ''
    context_notes = task_data['context_notes'] || ''
    
    email_reference = "\n\n---\n**Email Context:**\n"
    email_reference += "Subject: #{email_context[:subject]}\n"
    email_reference += "From: #{email_context[:from]&.first&.dig(:email)}\n"
    email_reference += "Date: #{email_context[:date]}\n"
    
    if context_notes.present?
      email_reference += "\n**Additional Context:** #{context_notes}\n"
    end
    
    base_description + email_reference
  end
end
