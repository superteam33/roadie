class TaskSerializer
  include JSONAPI::Serializer
  
  attributes :id, :title, :description, :status, :priority, :due_date, :created_at, :updated_at
  
  belongs_to :assignee, serializer: UserSerializer
  belongs_to :epic, serializer: EpicSerializer
  belongs_to :project, serializer: ProjectSerializer
  
  # Custom attribute for Kanban board display
  attribute :epic_name do |task|
    task.epic&.name
  end
  
  attribute :assignee_name do |task|
    task.assignee&.name
  end
  
  attribute :assignee_email do |task|
    task.assignee&.email
  end
  
  attribute :is_overdue do |task|
    task.due_date.present? && task.due_date < Time.current && !task.completed? && !task.cancelled?
  end
end
