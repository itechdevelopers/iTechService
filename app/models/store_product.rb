class StoreProduct < ApplicationRecord

  belongs_to :store, optional: true
  belongs_to :product, optional: true
  # attr_accessible :warning_quantity, :store_id, :product_id
  validates_presence_of :store
  validates_numericality_of :warning_quantity, only_integer: true, greater_than_or_equal_to: 0, allow_nil: true
  validates_uniqueness_of :product_id, scope: :store_id

end
