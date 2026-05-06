class RepairPauseReason < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(archived: false) }
  scope :ordered, -> { order(:position) }
end
