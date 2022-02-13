FactoryBot.define do
  factory :store_product do
    store
    product
    warning_quantity { 1 }
  end
end
