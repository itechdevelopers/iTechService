class Supply < ApplicationRecord

  belongs_to :supply_report, optional: true
  belongs_to :supply_category, optional: true
  # attr_accessible :name, :cost, :quantity, :supply_report_id, :supply_category_id
  validates_presence_of :name, :cost, :quantity, :supply_category

  delegate :name, to: :supply_category, prefix: :category, allow_nil: true

  def sum
    (cost || 0) * (quantity || 0)
  end

end
