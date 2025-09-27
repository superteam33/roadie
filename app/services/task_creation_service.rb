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

  private

  def parse_task_request(request_text, context)
    # Use OpenAI to parse the task request
    openai_service = OpenAIService.new
    parsed_data = openai_service.generate_roadmap(request_text, context)
    
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

    Task.create!(
      title: task_data['title'],
      description: task_data['description'],
      status: task_data['status'] || 'todo',
      priority: task_data['priority'] || 'medium',
      project: project,
      epic: epic,
      assignee: assignee,
      due_date: due_date
    )
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
end
