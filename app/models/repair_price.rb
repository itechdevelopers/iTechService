class RepairPrice < ApplicationRecord
  scope :in_department, ->(department) { where department_id: department }

  belongs_to :repair_service, inverse_of: :prices, optional: true
  belongs_to :department, optional: true

  # attr_accessible :value, :repair_service_id, :department_id
  validates_presence_of :department, :repair_service
  validates_presence_of :value, unless: -> { is_range_price? }
  validates_presence_of :value_from, :value_to, if: -> { is_range_price? }
  validates_uniqueness_of :department_id, scope: :repair_service_id

  def shown_price
    if is_range_price?
      "#{value_from} - #{value_to}"
    else
      "#{value}"
    end
  end
end
