FactoryBot.define do
  factory :item do
    product

    trait :featured do
      association :product, factory: :featured_product
    end

    trait :spare_part do
      association :product, :spare_part
    end

    factory :featured_item, traits: [:featured]

  end
end
