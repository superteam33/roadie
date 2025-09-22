class User < ApplicationRecord
  has_secure_password
  
  has_many :owned_projects, class_name: 'Project', foreign_key: 'owner_id'
  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assignee_id'
  has_many :agent_executions, dependent: :destroy
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin pm developer student] }
  
  enum :role, { admin: 'admin', pm: 'pm', developer: 'developer', student: 'student' }
  
  def integration_tokens
    JSON.parse(super || '{}')
  rescue JSON::ParserError
    {}
  end
  
  def integration_tokens=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
end
