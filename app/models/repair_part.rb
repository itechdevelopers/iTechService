class RepairPart < ApplicationRecord
  scope :in_department, ->(department) { where(repair_task_id: RepairTask.in_department(department)) }

  belongs_to :repair_task, inverse_of: :repair_parts
  belongs_to :item
  has_many :spare_part_defects, inverse_of: :repair_part

  delegate :name, :store_item, :code, :purchase_price, :product, to: :item, allow_nil: true
  delegate :department, :store, to: :repair_task, allow_nil: true

  attr_accessor :is_warranty, :contractor_id
  # attr_accessible :quantity, :warranty_term, :repair_task_id, :item_id, :spare_part_defects_attributes, :is_warranty, :contractor_id
  accepts_nested_attributes_for :spare_part_defects

  validates_presence_of :item
  validates_numericality_of :warranty_term, only_integer: true, greater_than_or_equal_to: 0

  after_initialize do
    self.warranty_term ||= item.try(:warranty_term)
  end

  def defect_qty
    return self['defect_qty'] if self['defect_qty'].present?

    spare_part_defects.sum(:qty)
  end

  def deduct_spare_parts
    result = false
    store_src = department.repair_store

    if store_src.present?
      result = store_item(store_src).dec(quantity)
    end
    !!result
  end

  def stash
    result = false
    store_src = department.spare_parts_store
    store_dst = department.repair_store

    if store_src.present? && store_dst.present?
      result = store_item(store_src).move_to(store_dst, quantity)
    end
    !!result
  end

  def unstash
    result = false
    store_src = department.repair_store
    store_dst = department.spare_parts_store

    if store_src.present? && store_dst.present?
      result = self.store_item(store_src).move_to(store_dst, self.quantity)
    end
    !!result
  end

  def last_batch_price
    item.batches.last_posted&.price
  end
end
