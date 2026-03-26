# frozen_string_literal: true

class FindMyDeviceCheck < ApplicationRecord
  COOLDOWN_PERIOD = 5.minutes

  belongs_to :user
  belongs_to :service_job, optional: true

  enum status: { unlocked: 0, locked: 1, error: 2 }

  validates :imei, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_imei, ->(imei) { where(imei: imei) }

  def self.imei_blocked?(imei)
    for_imei(imei)
      .where(status: :locked)
      .where('created_at > ?', COOLDOWN_PERIOD.ago)
      .exists?
  end
end
