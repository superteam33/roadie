class ProjectSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :description, :status, :created_at, :updated_at
  
  belongs_to :owner, serializer: UserSerializer
  
  has_many :epics
  has_many :tasks
  has_many :prds
  has_many :roadmaps
end
