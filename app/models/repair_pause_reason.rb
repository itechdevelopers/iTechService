class RepairPauseReason < ApplicationRecord
  has_many :repair_status_changes, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(archived: false) }
  scope :ordered, -> { order(:position) }
end
