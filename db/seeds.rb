# Create default agents
agents = [
  {
    name: 'PRD Generator',
    agent_type: 'prd_generator',
    status: 'active',
    capabilities: ['generate_prd', 'analyze_requirements', 'create_user_stories']
  },
  {
    name: 'Task Breaker',
    agent_type: 'task_breaker',
    status: 'active',
    capabilities: ['break_down_epics', 'create_tasks', 'estimate_effort']
  },
  {
    name: 'Roadmap Creator',
    agent_type: 'roadmap_creator',
    status: 'active',
    capabilities: ['create_roadmaps', 'plan_milestones', 'schedule_timeline']
  },
  {
    name: 'Status Updater',
    agent_type: 'status_updater',
    status: 'active',
    capabilities: ['update_status', 'track_progress', 'generate_reports']
  }
]

agents.each do |agent_data|
  Agent.find_or_create_by(name: agent_data[:name]) do |agent|
    agent.agent_type = agent_data[:agent_type]
    agent.status = agent_data[:status]
    agent.capabilities = agent_data[:capabilities]
  end
end

# Create a sample admin user
admin_user = User.find_or_create_by(email: 'admin@roadie.com') do |user|
  user.name = 'Roadie Admin'
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.role = 'admin'
end

# Create a sample project
if admin_user.persisted?
  sample_project = Project.find_or_create_by(name: 'Sample AI Project') do |project|
    project.description = 'A sample project to demonstrate Roadie capabilities'
    project.status = 'active'
    project.owner = admin_user
  end
  
  # Create sample epic
  if sample_project.persisted?
    sample_epic = Epic.find_or_create_by(name: 'User Authentication System') do |epic|
      epic.description = 'Implement user authentication and authorization'
      epic.status = 'in_progress'
      epic.priority = 'high'
      epic.project = sample_project
    end
    
    # Create sample tasks
    if sample_epic.persisted?
      tasks = [
        {
          title: 'Design authentication flow',
          description: 'Create wireframes and user flow for authentication',
          status: 'completed',
          priority: 'high',
          epic: sample_epic,
          project: sample_project,
          assignee: admin_user
        },
        {
          title: 'Implement JWT authentication',
          description: 'Set up JWT token generation and validation',
          status: 'in_progress',
          priority: 'high',
          epic: sample_epic,
          project: sample_project,
          assignee: admin_user
        },
        {
          title: 'Add password reset functionality',
          description: 'Implement password reset with email verification',
          status: 'todo',
          priority: 'medium',
          epic: sample_epic,
          project: sample_project
        }
      ]
      
      tasks.each do |task_data|
        Task.find_or_create_by(title: task_data[:title]) do |task|
          task.description = task_data[:description]
          task.status = task_data[:status]
          task.priority = task_data[:priority]
          task.epic = task_data[:epic]
          task.project = task_data[:project]
          task.assignee = task_data[:assignee]
        end
      end
    end
    
    # Create sample PRD
    Prd.find_or_create_by(title: 'User Authentication PRD') do |prd|
      prd.content = 'This PRD outlines the requirements for implementing a secure user authentication system...'
      prd.status = 'draft'
      prd.project = sample_project
    end
    
    # Create sample roadmap
    Roadmap.find_or_create_by(title: 'Q1 2024 Development Roadmap') do |roadmap|
      roadmap.description = 'Quarterly roadmap for core feature development'
      roadmap.project = sample_project
    end
  end
end

puts "Seeds completed successfully!"
puts "Created #{Agent.count} agents"
puts "Created #{User.count} users"
puts "Created #{Project.count} projects"
puts "Created #{Epic.count} epics"
puts "Created #{Task.count} tasks"
puts "Created #{Prd.count} PRDs"
puts "Created #{Roadmap.count} roadmaps"
