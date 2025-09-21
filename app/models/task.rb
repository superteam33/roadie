class Task < ApplicationRecord
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :epic, optional: true
  belongs_to :project
  
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[todo in_progress review completed cancelled] }
  validates :priority, presence: true, inclusion: { in: %w[low medium high critical] }
  
  enum status: { 
    todo: 'todo', 
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
  
  scope :by_assignee, ->(user) { where(assignee: user) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Time.current, ['completed', 'cancelled']) }
end
