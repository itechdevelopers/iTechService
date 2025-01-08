# frozen_string_literal: true

class ProductGroup < ApplicationRecord
  include Tree

  default_scope -> { ordered }
  scope :ordered, -> { order :position }
  scope :name_asc, -> { order('name asc') }
  scope :services, -> { joins(:product_category).where(product_categories: { kind: 'service' }) }
  scope :devices, -> { joins(:product_category).where(product_categories: { kind: 'equipment' }) }
  scope :goods, -> { joins(:product_category).where(product_categories: { kind: %w[equipment accessory] }) }
  scope :except_spare_parts, lambda {
                               joins(:product_category).where(product_categories: { kind: %w[equipment accessory protector service] })
                             }
  scope :except_spare_parts_and_services, lambda {
                                            joins(:product_category).where(product_categories: { kind: %w[equipment accessory protector] })
                                          }
  scope :except_services, lambda {
                            joins(:product_category).where(product_categories: { kind: %w[equipment accessory protector spare_part] })
                          }
  scope :spare_parts, -> { joins(:product_category).where(product_categories: { kind: 'spare_part' }) }
  scope :for_purchase, lambda {
                         joins(:product_category).where(product_categories: { kind: %w[equipment accessory protector spare_part] })
                       }
  scope :available_for_trade_in, -> { where(available_for_trade_in: true) }

  belongs_to :product_category
  has_many :trade_in_device_evaluations
  has_many :products, dependent: :nullify, inverse_of: :product_group
  has_many :product_relations, as: :parent, dependent: :destroy
  has_many :related_products, through: :product_relations, source: :relatable, source_type: 'Product'
  has_many :related_product_groups, through: :product_relations, source: :relatable, source_type: 'ProductGroup'
  has_and_belongs_to_many :option_values, join_table: 'product_groups_option_values', uniq: true
  has_and_belongs_to_many :repair_services
  has_many :option_types, -> { distinct }, through: :option_values

  delegate :feature_accounting, :feature_types, :warranty_term, :is_service, :is_equipment, :is_accessory,
           :is_spare_part, :request_price, to: :product_category, allow_nil: true
  delegate :kind, to: :product_category, prefix: :category, allow_nil: true

  validates_presence_of :name
  validates :code, uniqueness: { allow_blank: true, case_sensitive: false }

  after_initialize :set_product_category
  before_save :set_available_for_trade_in_to_children, if: :available_for_trade_in?
  before_save :unset_available_for_trade_in_to_children, unless: :available_for_trade_in?
  after_save :update_descendants_trademark, if: :saved_change_to_trademark?
  after_save :update_descendants_product_line, if: :saved_change_to_product_line?
  has_ancestry orphan_strategy: :restrict, cache_depth: true
  acts_as_list scope: [:ancestry]

  def self.search(roots: false, form: nil, store_kind: nil, user_role: nil, **)
    product_groups = roots ? ProductGroup.roots : ProductGroup.all

    if form.present?
      case form
      when 'repair_service' then product_groups = product_groups.spare_parts
      when 'purchase' then product_groups = product_groups.for_purchase
      when 'sale' then product_groups = product_groups.except_spare_parts_and_services
      when 'movement_act' then unless User.current.any_admin?
                                 product_groups = User.current.technician? ? product_groups.spare_parts : product_groups.except_spare_parts
                               end
      else product_groups
      end
    end

    if store_kind.present?
      case store_kind
      when 'spare_parts', 'defect_sp', 'repair' then product_groups = product_groups.spare_parts
      when 'purchase' then product_groups = product_groups.for_purchase
      else product_groups = product_groups.except_spare_parts_and_services
      end
    end

    if user_role.present?
      case user_role
      when 'software', 'universal' then product_groups = product_groups.except_spare_parts_and_services
      when 'technician' then product_groups = product_groups.spare_parts
      end
    end

    product_groups
  end

  def self.equipment_children
    equipment = find_by(code: 'equipment')
    equipment ? equipment.children : none
  end

  def available_options
    option_values.ordered.group_by { |ov| ov.option_type.name }
  end

  def available_trade_in_options
    option_values.trade_in.ordered.reject { |ov| ov.name == "?" }.group_by { |ov| ov.option_type.name }
  end

  def flatten_name
    parent_group_name = ProductGroup.find(ancestry.split("/").last.to_i).name
    "#{parent_group_name} -- #{self.name}"
  end

  private

  def set_product_category
    self.parent_id = nil if parent_id.blank?
    self.product_category_id ||= parent.product_category_id unless is_root?
  end

  def set_available_for_trade_in_to_children
    children.update_all(available_for_trade_in: true) if persisted?
  end

  def unset_available_for_trade_in_to_children
    children.update_all(available_for_trade_in: false) if persisted?
  end
  
  def update_descendants_trademark
    descendants.update_all(trademark: trademark)
  end

  def update_descendants_product_line
    descendants.update_all(product_line: product_line)
  end
end
