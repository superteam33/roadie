class Project < ApplicationRecord
  include UuidEncodable
  
  belongs_to :owner, class_name: 'User'
  has_many :epics, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :prds, dependent: :destroy
  has_many :roadmaps, dependent: :destroy
  
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: %w[planning active on_hold completed cancelled] }
  
  enum :status, { 
    planning: 'planning', 
    active: 'active', 
    on_hold: 'on_hold', 
    completed: 'completed', 
    cancelled: 'cancelled' 
  }
  
  scope :by_owner, ->(user) { where(owner: user) }
  scope :active_projects, -> { where(status: 'active') }
end
