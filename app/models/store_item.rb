class StoreItem < ActiveRecord::Base
  scope :in_store, ->(store) { where(store_id: store) }
  scope :available, ->{where('quantity > ?', 0)}
  scope :for_product, ->(product) { includes(:item).where(items: {product_id: (product.is_a?(Product) ? product.id : product)}) }

  belongs_to :item, inverse_of: :store_items
  belongs_to :store, inverse_of: :store_items

  delegate :feature_accounting, :features, :name, :code, :quantity_threshold, :comment, :product, :product_group, :purchase_price, :retail_price, :features_s, to: :item, allow_nil: true
  delegate :name, :code, to: :store, prefix: true, allow_nil: true

  # attr_accessible :item_id, :store_id, :quantity
  validates_presence_of :item, :store, :quantity
  validates_uniqueness_of :item_id, scope: :store_id
  validates_numericality_of :quantity, only_integer: true
  validates_numericality_of :quantity, only_integer: true, equal_to: 1, if: :feature_accounting
  after_save :warn_of_low_remnants
  before_destroy :warn_of_low_remnants

  def self.search(params)
    store_items = self.all

    if (product_group_id = params[:product_group_id]).present?
      store_items = store_items.includes(item: :product).where(products: {product_group_id: product_group_id})
    end

    store_items
  end

  def add(amount = 1)
    unless feature_accounting
      amount = amount.to_i
      update_attribute :quantity, (self.quantity || 0) + amount if amount.is_a? Integer
    end
  end

  def dec(amount = 1)
    if feature_accounting
      false
    else
      amount = amount.to_i
      update_attribute :quantity, (self.quantity || 0) - amount if amount.is_a? Integer
    end
  end

  def move_to(dst_store, amount=0)
    if feature_accounting
      update_attribute :store_id, dst_store.id
    else
      dec amount
      if (store_item = StoreItem.find_by_item_id_and_store_id(item_id, dst_store.id)).present?
        store_item.add amount
      else
        StoreItem.create store_id: dst_store.id, item_id: item_id, quantity: amount
      end
    end
  end

  private

  def warn_of_low_remnants
    if product.present? and (warning_quantity = product.warning_quantity_for_store(store)).present?
      if product.quantity_in_store(store).pred <= warning_quantity
        RemnantsMailer.warning(product.id, store.id).deliver_later
      end
    end
  end

end
