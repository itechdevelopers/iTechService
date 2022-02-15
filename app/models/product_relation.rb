class ProductRelation < ApplicationRecord

  belongs_to :parent, polymorphic: true, optional: true
  belongs_to :relatable, polymorphic: true, optional: true

end
