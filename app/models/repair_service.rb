# frozen_string_literal: true

class RepairService < ApplicationRecord
  default_scope { order('repair_services.name asc') }
  scope :in_group, ->(group) { where repair_group_id: group }
  scope :with_spare_part_name, ->(query) {
    joins(spare_parts: :product).
    where('products.name ilike :q', q: "%#{query}%")
  }
  scope :search, ->(query) { query.present? ?
    # left_joins(spare_parts: :product).
    # where('repair_services.name ilike :q COLLATE "ru_RU.UTF-8" OR products.name ilike :q COLLATE "ru_RU.UTF-8"', q: "%#{query}%").
    left_joins(spare_parts: :product).
    where('repair_services.name ilike :q COLLATE "ru_RU.utf8" OR products.name ilike :q COLLATE "ru_RU.utf8"', q: "%#{query}%").
    distinct :
    all
  }
  scope :archived, -> { where(archived: true) }
  scope :not_archived, -> { where(archived: false) }

  belongs_to :repair_group, optional: true
  has_many :spare_parts, dependent: :destroy
  has_many :store_items, through: :spare_parts
  has_many :prices, class_name: 'RepairPrice', inverse_of: :repair_service, dependent: :destroy
  has_many :repair_tasks, dependent: :restrict_with_error
  has_and_belongs_to_many :repair_causes
  has_and_belongs_to_many :products

  accepts_nested_attributes_for :spare_parts, allow_destroy: true
  accepts_nested_attributes_for :prices
  validates_presence_of :name
  validates_associated :spare_parts

  def find_price(department)
    prices.in_department(department).first
    # Убираем N+1 запрос
    # prices.find { |price| price.department_id == department.id }
  end

  def price(department = nil)
    department ||= Department.current
    find_price(department)
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

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end
end
