FactoryBot.define do
  factory :store_item do
    item
    store
    quantity { 0 }
  end

  trait :featured do
    association :item, factory: :featured_item
  end
end
