class RepairStatusChange < ApplicationRecord
  belongs_to :service_job
  belongs_to :from_status, class_name: 'RepairStatus', optional: true
  belongs_to :to_status, class_name: 'RepairStatus'
  belongs_to :repair_pause_reason, optional: true
  belongs_to :user, optional: true
  belongs_to :displaced_by_service_job, class_name: 'ServiceJob', optional: true

  validates :changed_at, presence: true

  scope :chronological, -> { order(:changed_at) }
end
