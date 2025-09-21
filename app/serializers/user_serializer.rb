class UserSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :email, :role, :created_at, :updated_at
  
  attribute :integration_tokens do |user|
    user.integration_tokens
  end
end
