class DeductionItem < ActiveRecord::Base
  belongs_to :item
  belongs_to :deduction_act, inverse_of: :deduction_items
  delegate :code, :name, :product, :product_category, :presentation, :features, :feature_accounting, :store_items, :store_item, :quantity_in_store, :remove_from_store, to: :item, allow_nil: true
  delegate :store, to: :deduction_act, allow_nil: true
  # attr_accessible :quantity, :item_id, :deduction_act_id
  validates_presence_of :item, :quantity, :deduction_act
  validates_numericality_of :quantity, only_integer: true, greater_than: 0, unless: :feature_accounting
  validates_numericality_of :quantity, only_integer: true, equal_to: 1, if: :feature_accounting

  def is_insufficient?
    store.present? ? quantity_in_store(store) < quantity : false
  end

  def last_purchase_price
    item&.batches&.last_posted&.price
  end
end
