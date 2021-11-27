class ProductRelation < ApplicationRecord

  belongs_to :parent, polymorphic: true
  belongs_to :relatable, polymorphic: true

end
