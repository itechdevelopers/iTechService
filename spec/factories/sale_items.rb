FactoryBot.define do
  factory :sale_item do
    price { 1000 }
    quantity { 1 }
    sale
    item

    factory :featured_sale_item do
      association(:item, factory: :featured_item)
    end

  end
end
