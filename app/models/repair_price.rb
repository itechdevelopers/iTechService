class RepairPrice < ApplicationRecord
  scope :in_department, ->(department) { where department_id: department }

  belongs_to :repair_service, inverse_of: :prices
  belongs_to :department

  validates_presence_of :department, :repair_service, :value
  validates_uniqueness_of :department_id, scope: :repair_service_id
end
