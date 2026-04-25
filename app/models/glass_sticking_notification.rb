class GlassStickingNotification < ApplicationRecord
  belongs_to :sender, class_name: 'User'
  belongs_to :recipient, class_name: 'User'
  belongs_to :department

  enum status: { ready: 0, problem: 1 }

  validates :status, presence: true
end
