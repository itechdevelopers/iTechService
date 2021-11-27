# Для однократного применения
# deprecated
class MoveBarcode
  prepend BaseInteractor

  class Product < ActiveRecord::Base
    belongs_to :product_category
    has_many :items

    def item
      product_category.feature_accounting ? nil : items.first
    end
  end

  def call
    category_ids = ProductCategory.where(feature_accounting: false).ids

    Product.where(product_category_id: category_ids)
      .preload(:items, :product_category)
      .find_in_batches do |batch|
      batch.each do |product|
        next unless (item = product.item)

        product.update(barcode_num: item.barcode_num)
      end
    end
  end
end