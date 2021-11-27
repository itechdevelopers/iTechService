class Revaluation < ApplicationRecord

  belongs_to :revaluation_act, inverse_of: :revaluations
  belongs_to :product, inverse_of: :revaluations

  delegate :code, :name, :prices, :purchase_price, :retail_price, to: :product, allow_nil: true

  # attr_accessible :price, :product_id, :revaluation_act_id
  validates_presence_of :revaluation_act, :product, :price

  after_initialize do
    self.price ||= (self.retail_price || 0)
  end

end
