# frozen_string_literal: true

class Store < ActiveRecord::Base
  # TODO: change kind type to integer
  KINDS = %w[purchase retail spare_parts defect defect_sp repair].freeze

  default_scope { order(hidden: :desc, name: :asc) }
  scope :in_department, ->(department) { where(department_id: department) }
  scope :ordered, -> { order('id asc') }
  scope :for_purchase, -> { joins(:price_types).where(price_types: { kind: 0 }) }
  scope :for_retail, -> { joins(:price_types).where(price_types: { kind: 1 }) }
  scope :defect, -> { where(kind: 'defect') }
  scope :defect_sp, -> { where(kind: 'defect_sp') }
  scope :purchase, -> { where(kind: 'purchase') }
  scope :retail, -> { where(kind: 'retail') }
  scope :repair, -> { where(kind: 'repair') }
  scope :spare_parts, -> { where(kind: 'spare_parts') }
  scope :visible, -> { where(hidden: [false, nil]) }

  belongs_to :department
  has_many :purchases, inverse_of: :store
  has_many :sales, inverse_of: :store
  has_many :movement_acts
  has_many :store_items, inverse_of: :store
  has_many :items, through: :store_items
  has_many :products, through: :items
  has_and_belongs_to_many :price_types
  has_many :store_products, dependent: :destroy

  delegate :name, to: :department, prefix: true, allow_nil: true
  validates_presence_of :name, :kind, :department

  def self.search(params)
    stores = all

    unless (kind = params[:kind]).blank?
      stores = stores.where kind: kind
    end

    stores
  end

  def self.spare_part_ids
    visible.spare_parts.map(&:id)
  end

  def self.current_defect_sp
    visible.defect_sp.in_department(Department.current).first
  end

  def self.for_retail
    visible.retail.first
  end

  def self.for_spare_parts
    visible.spare_parts.first
  end

  def is_spare_parts?
    kind == 'spare_parts'
  end

  def is_defect?
    kind.in? %w[defect defect_sp]
  end
end
