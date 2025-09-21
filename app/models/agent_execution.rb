class AgentExecution < ApplicationRecord
  belongs_to :agent
  belongs_to :user, optional: true
  
  validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }
  validates :execution_time, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  enum status: { 
    pending: 'pending', 
    running: 'running', 
    completed: 'completed', 
    failed: 'failed' 
  }
  
  def input_data
    JSON.parse(input || '{}')
  rescue JSON::ParserError
    {}
  end
  
  def input_data=(value)
    self.input = value.is_a?(String) ? value : value.to_json
  end
  
  def output_data
    JSON.parse(output || '{}')
  rescue JSON::ParserError
    {}
  end
  
  def output_data=(value)
    self.output = value.is_a?(String) ? value : value.to_json
  end
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_agent, ->(agent) { where(agent: agent) }
end
