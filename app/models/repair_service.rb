# frozen_string_literal: true

class RepairService < ActiveRecord::Base
  default_scope { order('name asc') }
  scope :in_group, ->(group) { where repair_group_id: group }

  belongs_to :repair_group
  has_many :spare_parts, dependent: :destroy
  has_many :store_items, through: :spare_parts
  has_many :prices, class_name: 'RepairPrice', inverse_of: :repair_service, dependent: :destroy
  has_many :repair_tasks, dependent: :restrict_with_error

  accepts_nested_attributes_for :spare_parts, allow_destroy: true
  accepts_nested_attributes_for :prices
  validates_presence_of :name, :repair_group
  validates_associated :spare_parts

  def find_price(department)
    prices.in_department(department).first
  end

  def price(department = nil)
    department ||= Department.current
    find_price(department)&.value
  end

  def total_cost
    spare_parts.to_a.sum { |sp| sp.purchase_price || 0 }
  end

  def remnants_s(store)
    %w[none low many][spare_parts.map { |sp| sp.remnant_status(store) }.min] if spare_parts.present?
  end

  def remnants_qty(department)
    store_items.in_store(Store.in_department(department).spare_parts).sum(:quantity)
  end
end
