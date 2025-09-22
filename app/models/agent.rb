class Agent < ApplicationRecord
  has_many :agent_executions, dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  validates :agent_type, presence: true, inclusion: { in: %w[prd_generator task_breaker roadmap_creator status_updater] }
  validates :status, presence: true, inclusion: { in: %w[active inactive maintenance] }
  
  enum :agent_type, { 
    prd_generator: 'prd_generator', 
    task_breaker: 'task_breaker', 
    roadmap_creator: 'roadmap_creator', 
    status_updater: 'status_updater' 
  }
  
  enum :status, { 
    active: 'active', 
    inactive: 'inactive', 
    maintenance: 'maintenance' 
  }
  
  def capabilities
    JSON.parse(super || '[]')
  rescue JSON::ParserError
    []
  end
  
  def capabilities=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  scope :active_agents, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(agent_type: type) }
end
