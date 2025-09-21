class AgentSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :agent_type, :status, :created_at, :updated_at
  
  attribute :capabilities do |agent|
    agent.capabilities
  end
end
