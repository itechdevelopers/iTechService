class SparePartDefect < ApplicationRecord
  include Auditable

  scope :in_department, ->(department) { where(repair_part_id: RepairPart.in_department(department)) }

  scope :new_records, -> { where(id: nil) }
  scope :warranty, -> { where(is_warranty: true) }
  scope :no_warranty, -> { where(is_warranty: false) }

  belongs_to :item, optional: true
  belongs_to :repair_part, inverse_of: :spare_part_defects, optional: true
  belongs_to :contractor, optional: true

  delegate :department, to: :repair_part
  delegate :store_item, to: :item

  # attr_accessible :item_id, :repair_part_id, :contractor_id, :qty, :is_warranty
  validates_presence_of :qty
  validates_numericality_of :qty, only_integer: true, greater_than: 0
  audited
end
