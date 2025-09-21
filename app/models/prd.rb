class Prd < ApplicationRecord
  belongs_to :project
  
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft review approved rejected] }
  
  enum status: { 
    draft: 'draft', 
    review: 'review', 
    approved: 'approved', 
    rejected: 'rejected' 
  }
  
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
end
