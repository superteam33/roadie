class UserSerializer
  include JSONAPI::Serializer
  
  attributes :id, :first_name, :last_name, :email, :role, :created_at, :updated_at
  
  attribute :full_name do |user|
    user.full_name
  end
  
  attribute :integration_tokens do |user|
    user.integration_tokens
  end
  
  # Exclude sensitive information
  attribute :slack_user_id, if: proc { |user, params| params&.dig(:include_slack_id) }
end
