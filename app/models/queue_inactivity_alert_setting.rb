class QueueInactivityAlertSetting < ApplicationRecord
  belongs_to :electronic_queue
  belongs_to :schedule_group
  has_and_belongs_to_many :occupation_types

  validates :electronic_queue_id, uniqueness: true
  validates :min_unattended_seconds,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
end
