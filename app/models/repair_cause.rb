class RepairCause < ApplicationRecord
  belongs_to :repair_cause_group
  has_and_belongs_to_many :repair_services

  validates :title, presence: true
end

