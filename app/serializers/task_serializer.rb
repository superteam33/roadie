class TaskSerializer
  include JSONAPI::Serializer
  
  attributes :id, :title, :description, :status, :priority, :created_at, :updated_at
  
  belongs_to :assignee, serializer: UserSerializer
  belongs_to :epic
  belongs_to :project, serializer: ProjectSerializer
end
