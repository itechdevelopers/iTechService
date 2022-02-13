FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:code)
    product_group
    device_type

    trait :service do
      association :product_group, factory: :service_product_group
    end

    trait :spare_part do
      association :product_group, factory: :spare_part_product_group
    end

    factory :featured_product do
      association :product_group, factory: :featured_product_group
    end
  end
end
