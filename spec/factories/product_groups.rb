FactoryBot.define do
  factory :product_group do
    name { 'Product group 1' }
    ancestry { nil }
    product_category

    factory :service_product_group do
      association :product_category, :service
    end

    factory :spare_part_product_group do
      association :product_category, :spare_part
    end

    factory :featured_product_group do
      association :product_category, factory: :featured_product_category
    end
  end
end
