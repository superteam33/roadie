class UserSession < ApplicationRecord
  belongs_to :user
  
  validates :access_token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :is_active, inclusion: { in: [true, false] }
  
  scope :active, -> { where(is_active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid, -> { active.where('expires_at > ?', Time.current) }
  
  def expired?
    expires_at < Time.current
  end
  
  def deactivate!
    update!(is_active: false)
  end
  
  def self.cleanup_expired
    expired.update_all(is_active: false)
  end
end
