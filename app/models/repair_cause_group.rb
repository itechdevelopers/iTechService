class RepairCauseGroup < ApplicationRecord
  has_many :repair_causes

  validates :title, presence: true
end
