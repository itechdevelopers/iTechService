class Revaluation < ApplicationRecord

  belongs_to :revaluation_act, inverse_of: :revaluations, optional: true
  belongs_to :product, inverse_of: :revaluations, optional: true

  delegate :code, :name, :prices, :purchase_price, :retail_price, to: :product, allow_nil: true

  validates_presence_of :revaluation_act, :product, :price

  after_initialize do
    self.price ||= (self.retail_price || 0)
  end

end
