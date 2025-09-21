class Roadmap < ApplicationRecord
  belongs_to :project
  
  validates :title, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
end
