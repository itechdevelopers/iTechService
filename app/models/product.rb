# frozen_string_literal: true

class Product < ApplicationRecord
  BARCODE_PREFIX = '243'

  scope :name_asc, -> { order('name asc') }
  scope :available, -> { includes(:store_items).where('store_items.quantity > ?', 0).references(:store_items) }
  scope :in_store, lambda { |store|
                     includes(:store_items).where(store_items: { store_id: store.is_a?(Store) ? store.id : store }).references(:store_items)
                   }
  scope :devices, -> { joins(product_group: :product_category).where(product_categories: { kind: 'equipment' }) }
  scope :goods, lambda {
                  joins(product_group: :product_category).where(product_categories: { kind: %w[equipment accessory protector] })
                }
  scope :services, -> { joins(product_group: :product_category).where(product_categories: { kind: 'service' }) }
  scope :spare_parts, -> { joins(product_group: :product_category).where(product_categories: { kind: 'spare_part' }) }
  scope :defined, -> { where.not code: '?' }
  scope :undefined, -> { where code: '?' }
  scope :with_type_and_options, lambda { |product_type_id, option_ids|
                                  product_type_id.present? && option_ids.present? ? where(id: includes(:options).where(product_type_id: product_type_id, product_options: { option_value_id: option_ids }).group('product_options.product_id').having('count(product_options.product_id) = ?', option_ids.length).count('products.id').keys.first) : none
                                }

  scope :in_group, ->(group) { where(product_group_id: ProductGroup.descendants_of(group)) }

  belongs_to :product_category, inverse_of: :products, optional: true
  belongs_to :product_group, inverse_of: :products, optional: true
  belongs_to :device_type, inverse_of: :product, optional: true
  has_one :task, inverse_of: :product, dependent: :nullify
  has_one :top_salable, dependent: :nullify
  has_and_belongs_to_many :options, class_name: 'OptionValue', join_table: 'product_options'
  has_many :option_types, -> { ordered.distinct }, through: :product_group
  has_many :option_values, through: :product_group
  has_many :items, inverse_of: :product, dependent: :restrict_with_error
  has_many :prices, class_name: 'ProductPrice', inverse_of: :product, dependent: :destroy
  has_many :store_items, through: :items
  has_many :batches, through: :items
  has_many :revaluations, inverse_of: :product, dependent: :destroy
  has_many :product_relations, as: :parent, dependent: :destroy
  has_many :related_products, through: :product_relations, source: :relatable, source_type: 'Product'
  has_many :related_product_groups, through: :product_relations, source: :relatable, source_type: 'ProductGroup'
  has_many :store_products, dependent: :destroy
  has_many :spare_parts, dependent: :destroy

  accepts_nested_attributes_for :items, allow_destroy: true
  accepts_nested_attributes_for :task, allow_destroy: false
  accepts_nested_attributes_for :store_products

  alias_attribute :defined?, :options_defined?

  delegate :feature_accounting, :feature_types, :is_service, :is_equipment, :is_spare_part, :is_service?,
           :is_equipment?, :is_spare_part?, :request_price, to: :product_category, allow_nil: true
  delegate :name, to: :product_category, prefix: :category, allow_nil: true
  delegate :available_options, to: :product_group, allow_nil: true
  delegate :warranty_term, to: :product_group, prefix: :default, allow_nil: true
  delegate :name, to: :product_group, prefix: 'group', allow_nil: true
  delegate :full_name, to: :device_type, prefix: true, allow_nil: true
  delegate :color, to: :top_salable, allow_nil: true
  delegate :cost, to: :task, prefix: true, allow_nil: true

  validates_presence_of :name, :code, :product_group, :product_category
  # validates_presence_of :device_type, if: :is_equipment
  validates_uniqueness_of :code, unless: :undefined?
  validates :barcode_num, length: {is: 13}, uniqueness: true, allow_nil: true, allow_blank: true
  validates :article, uniqueness: true, allow_blank: true

  before_validation :normalize_article

  after_initialize do
    self.warranty_term ||= default_warranty_term
    self.product_category_id ||= product_group.try(:product_category).try(:id)
    # self.build_task if self.is_service and self.task.nil?
  end

  after_create :generate_barcode_num

  def self.search(params)
    products = Product.all
    query = params[:query] || params[:q]

    unless query.blank?
      query = query.mb_chars.downcase.to_s
      products = products.includes(items: :features).references(:features, :items)
                         .where('LOWER(products.name) LIKE :ql OR products.code LIKE :ql OR features.value = :q OR items.barcode_num = :q OR products.article = :q',
                                q: query, ql: "%#{query}%")
    end

    unless (product_group_id = params[:product_group_id]).blank?
      products = products.where(products: { product_group_id: product_group_id })
    end

    products
  end

  def self.find_by_group_and_options(product_group_id, option_ids = nil)
    if product_group_id.present? && option_ids.present?
      where(id: includes(:options).where(product_group_id: product_group_id, product_options: { option_value_id: option_ids }).group('product_options.product_id').having(
        'count(product_options.product_id) = ?', option_ids.length
      ).count('products.id').keys.first).first
    elsif product_group_id.present? && option_ids.blank? && ProductGroup.find(product_group_id).option_values.none?
      (products = where(product_group_id: product_group_id)).many? ? nil : products.first
    end
  end

  def product_item
    items.first_or_create!
  end

  def object_kind_for_order
    device_group_id = ProductGroup.where('name LIKE ?', '%Техника%').first.id
    sp_group_id = ProductGroup.where('name LIKE ?', '%Запчасти%').first.id
    groups_id = product_group.ancestry.split('/').map(&:strip).map(&:to_i)
    if groups_id.include? device_group_id
      'device'
    elsif groups_id.include? sp_group_id
      'spare_part'
    else
      ''
    end
  end

  def generate_barcode_num
    return unless barcode_num.blank?

    num = id.to_s
    code = Product::BARCODE_PREFIX + '0' * (9 - num.length) + num
    update_attribute :barcode_num, Barby::EAN13.new(code).to_s
  end

  def actual_price(price_type)
    prices.with_type(price_type).first.try(:value)
  end

  def purchase_price
    is_service ? task_cost : prices.purchase.first.try(:value)
  end

  def retail_price
    is_service ? task_cost : prices.retail.first.try(:value)
  end

  def actual_prices
    {
      purchase: purchase_price,
      retail: retail_price
    }
  end

  def batch_price_on(date)
    batches.for_date(date).newest.last&.price
  end

  def quantity_in_store(store = nil)
    if store.present?
      store_items.in_store(store).sum(:quantity)
    else
      store_items.sum(:quantity)
    end
  end

  def quantity_by_stores
    Store.visible.collect { |store| { id: id, code: store.code, name: store.name, quantity: quantity_in_store(store) } }
  end

  # def item
  #   feature_accounting ? nil : items.first_or_create
  # end

  def discount_for(client)
    client.present? ? Discount.available_for(client, self) : 0
  end

  def remnants_hash
    res = {}
    Store.visible.retail.each { |store| res.store store.code, quantity_in_store(store) }
    res
  end

  def remnant_s(store)
    value = quantity_in_store(store) || 0
    if value <= 0
      'none'
    elsif value > (quantity_threshold || 0)
      'many'
    else
      'low'
    end
  end

  def remnant_status(store)
    value = quantity_in_store(store) || 0
    if value <= 0
      0
    elsif value > (quantity_threshold || 0)
      2
    else
      1
    end
  end

  def warning_quantity_for_store(store)
    store_products.find_by_store_id(store.id).try(:warning_quantity)
  end

  def remnants_cost
    quantity_in_store * (purchase_price || 0)
  end

  def is_repair?
    code.present? and code.start_with? 'repair'
  end

  def options_defined?
    !options.exists?(code: '?')
  end

  def undefined?
    code == '?'
  end

  def normalize_article
    self.article = nil if article.blank?
  end
end
