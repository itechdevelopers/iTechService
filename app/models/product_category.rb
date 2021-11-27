class ProductCategory < ApplicationRecord

  KINDS = %w[equipment accessory service protector spare_part]

  has_many :product_groups, inverse_of: :product_category
  has_many :products, inverse_of: :product_category
  has_and_belongs_to_many :feature_types, uniq: true
  # attr_accessible :name, :kind, :feature_accounting, :request_price, :warranty_term, :feature_type_ids
  validates_presence_of :name, :kind
  validates_inclusion_of :kind, in: KINDS

  before_save do |product_category|
    product_category.feature_accounting = product_category.feature_type_ids.any?
    true
  end

  def is_service?
    kind == 'service'
  end
  alias_method :is_service, :is_service?

  def is_equipment?
    kind == 'equipment'
  end
  alias_method :is_equipment, :is_equipment?

  def is_accessory?
    kind == 'accessory'
  end
  alias_method :is_accessory, :is_accessory?

  def is_spare_part?
    kind == 'spare_part'
  end
  alias_method :is_spare_part, :is_spare_part?

  def self.accessory_with_sn
    ProductCategory.where(kind: 'accessory').includes(:feature_types).where('feature_types.kind = ?', 'serial_number').first || ProductCategory.create(name: 'Accessory with SN', kind: 'accessory', feature_type_ids: [FeatureType.serial_number.id])
  end

  def self.equipment_with_imei
    ProductCategory.where(kind: 'equipment').includes(:feature_types).where('feature_types.kind = ?', 'imei').first || ProductCategory.create(kind: 'equipment', feature_type_ids: [FeatureType.serial_number.id, FeatureType.imei.id])
  end

end
