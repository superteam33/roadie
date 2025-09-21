class Epic < ApplicationRecord
  belongs_to :project
  has_many :tasks, dependent: :destroy
  
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: %w[backlog in_progress review completed cancelled] }
  validates :priority, presence: true, inclusion: { in: %w[low medium high critical] }
  
  enum status: { 
    backlog: 'backlog', 
    in_progress: 'in_progress', 
    review: 'review', 
    completed: 'completed', 
    cancelled: 'cancelled' 
  }
  
  enum priority: { 
    low: 'low', 
    medium: 'medium', 
    high: 'high', 
    critical: 'critical' 
  }
  
  scope :by_priority, -> { order(priority: :desc) }
  scope :by_status, ->(status) { where(status: status) }
end
