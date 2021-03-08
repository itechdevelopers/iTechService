# frozen_string_literal: true

require 'barby/barcode/ean_13'
class Item < ActiveRecord::Base
  scope :available, -> { includes(:store_items).where('store_items.quantity > ?', 0).references(:store_items) }
  scope :in_store, lambda { |store|
                     includes(:store_items).where(store_items: { store_id: store.is_a?(Store) ? store.id : store })
                   }

  belongs_to :product, inverse_of: :items
  has_many :store_items, inverse_of: :item, dependent: :destroy
  has_many :batches, inverse_of: :item, dependent: :destroy
  has_many :sale_items, inverse_of: :item, dependent: :destroy
  has_many :movement_items, inverse_of: :item, dependent: :destroy
  has_many :features, inverse_of: :item, dependent: :destroy
  has_many :sales, through: :sale_items
  has_one :stolen_phone
  has_one :substitute_phone
  has_one :trade_in_device
  accepts_nested_attributes_for :features, allow_destroy: true

  delegate :name, :code, :feature_accounting, :prices, :feature_types, :retail_price, :actual_prices,
           :quantity_in_store, :product_category, :product_group, :product_group_id, :discount_for, :is_service, :is_equipment, :is_spare_part, :is_equipment?, :is_spare_part?, :is_service?, :is_repair?, :request_price, :warranty_term, :quantity_threshold, :comment, :options, :option_ids, :available_options, to: :product, allow_nil: true

  validates_presence_of :product
  validates_length_of :barcode_num, is: 13, allow_nil: true
  validates_uniqueness_of :barcode_num, allow_nil: true
  validates_uniqueness_of :product_id, unless: :feature_accounting

  # attr_accessible :product, :product_id, :features_attributes, :barcode_num

  paginates_per 5

  after_create :generate_barcode_num

  def as_json(_options = {})
    {
      id: id,
      barcode_num: barcode_num,
      product_id: product_id,
      name: name,
      code: code,
      features: features,
      prices: actual_prices,
      quantity: quantity_in_store
    }
  end

  def self.search(params)
    items = Item.all

    unless (q = params[:q]).blank?
      items = items.includes(:features, :product).where(
        'features.value = :q OR products.code = :q OR items.barcode_num = :q OR LOWER(products.name) LIKE :ql', q: q, ql: "%#{q.mb_chars.downcase}%"
      ).references(:features)
    end

    items
  end

  def self.filter(params = {})
    items = Item.all
    unless (search = params[:search] || params[:term]).blank?
      search.chomp.split(/\s+/).each do |q|
        items = items.joins(:features).includes(:product).where(
          'LOWER(features.value) LIKE :q OR LOWER(products.code) LIKE :q OR items.barcode_num LIKE :q OR LOWER(products.name) LIKE :q', q: "%#{q.mb_chars.downcase}%"
        ).references(:products)
      end
    end
    items
  end

  def store_item(store = nil)
    if feature_accounting
      store_items.first
    elsif store.present?
      store_items.in_store(store).first_or_create quantity: 0
    end
  end

  def serial_number
    features.serial_number.first.try(:value)
  end

  def imei
    features.imei.first.try(:value)
  end

  def presentation
    [name, serial_number, imei].join(' / ')
  end

  def has_imei?
    features.imei.present?
  end

  def product_group_name
    product&.group_name
  end

  def add_to_store(store, amount)
    if store.present? && store.is_a?(Store)
      if feature_accounting
        if store_items.any?
          false
        else
          store_items.create store_id: store.id, quantity: 1
        end
      else
        store_item(store).add amount
      end
    end
  end

  def remove_from_store(store, amount = nil)
    if store.present? && store.is_a?(Store)
      if feature_accounting
        if store_item.present?
          store_item.destroy
        else
          false
        end
      elsif amount.nil?
        store_item(store).update_attribute :quantity, 0
      elsif store_item(store).quantity < amount
        false
      else
        store_item(store).dec amount
      end
    end
  end

  def actual_quantity(store = nil)
    if store.present?
      store_items.in_store(store).try(:first).try(:quantity) || 0
    else
      store_items.sum(:quantity)
    end
  end

  def generate_barcode_num
    if barcode_num.blank?
      num = id.to_s
      code = Product::BARCODE_PREFIX + '0' * (9 - num.length) + num
      update_attribute :barcode_num, Barby::EAN13.new(code).to_s
    end
  end

  def purchase_price
    feature_accounting ? batches.last_posted.try(:price) || product.purchase_price : product.purchase_price
  end

  def features_s
    features.collect(&:value).join(', ')
  end

  def sale_info
    if (posted_sales = sales.posted.order('date asc')).present?
      # {sale_info: {date: sale.date, is_return: sale.is_return, price: sale_items.where(sale_id: sale.id).first.price}}
      # {sale_info: "[#{sale.date.strftime('%d.%m.%y')}: #{'-' if sale.is_return}#{sale_items.where(sale_id: sale.id).first.price}]"}
      { sale_info: posted_sales.map do |s|
                     "[#{s.date.strftime('%d.%m.%y')}: #{if s.is_return
                                                           '-'
                                                         end}#{sale_items.where(sale_id: s.id).first.price}]"
                   end.join(' ') }
    else
      {}
    end
  end
end
