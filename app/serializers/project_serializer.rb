class ProjectSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :description, :status, :created_at, :updated_at
  
  belongs_to :owner, serializer: UserSerializer
end
