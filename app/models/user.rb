class User < ApplicationRecord
  include UuidEncodable
  
  has_secure_password
  
  has_many :owned_projects, class_name: 'Project', foreign_key: 'owner_id'
  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assignee_id'
  has_many :agent_executions, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin manager member] }
  
  # Slack integration fields
  validates :slack_user_id, uniqueness: true, allow_nil: true
  
  # GitHub integration fields
  validates :github_username, uniqueness: true, allow_nil: true
  
  enum :role, { admin: 'admin', manager: 'manager', member: 'member' }
  
  # Virtual attribute for full name
  def full_name
    "#{first_name} #{last_name}"
  end
  
  # Session management methods
  def create_session!
    # Deactivate all existing sessions
    user_sessions.active.update_all(is_active: false)
    
    # Create new session
    access_token = generate_access_token
    expires_at = 24.hours.from_now
    
    user_sessions.create!(
      access_token: access_token,
      expires_at: expires_at,
      is_active: true
    )
  end
  
  def active_session
    user_sessions.valid.first
  end
  
  def logout!
    user_sessions.active.update_all(is_active: false)
  end
  
  private
  
  def generate_access_token
    # Generate a secure random token
    SecureRandom.urlsafe_base64(32)
  end
  
  public
  
  def integration_tokens
    JSON.parse(super || '{}')
  rescue JSON::ParserError
    {}
  end
  
  def integration_tokens=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
end
