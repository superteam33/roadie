class EpicSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :description, :status, :priority, :created_at, :updated_at
  
  belongs_to :project, serializer: ProjectSerializer
end
