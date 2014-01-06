class MovementItem < ActiveRecord::Base

  belongs_to :movement_act, inverse_of: :movement_items
  belongs_to :item, inverse_of: :movement_items
  attr_accessible :movement_act_id, :item_id, :quantity
  validates_presence_of :movement_act, :item, :quantity
  validates_numericality_of :quantity, only_integer: true, greater_than: 0, unless: :feature_accounting
  validates_numericality_of :quantity, only_integer: true, equal_to: 1, if: :feature_accounting
  delegate :code, :name, :product, :product_category, :presentation, :features, :feature_accounting, :store_items, :store_item, :quantity_in_store, to: :item, allow_nil: true
  delegate :store, to: :movement_act, allow_nil: true

  def is_insufficient?
    store.present? ? quantity_in_store(store) < quantity : false
  end

  def has_prices_for_store?(store)
    store.price_types.all? { |price_type| product.prices.with_type(price_type).present? }
  end

end
