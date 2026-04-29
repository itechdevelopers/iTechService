class QueueInactivityAlertSetting < ApplicationRecord
  belongs_to :electronic_queue
  belongs_to :schedule_group

  validates :electronic_queue_id, uniqueness: true
  validates :min_unattended_seconds,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
end
