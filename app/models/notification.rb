class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :referenceable, polymorphic: true, optional: true

  scope :not_closed, -> { where(closed_at: nil) }

  validates :user_id, :message, presence: true

  def close
    update(closed_at: Time.zone.now)
  end

  def closed?
    closed_at.present?
  end
end