FactoryBot.define do
  factory :product_category do
    sequence(:name) {|n| "Category_#{n}"}
    feature_accounting { false }
    kind { ProductCategory::KINDS[0] }
    request_price { false }
    warranty_term { 12 }

    trait :service do
      kind { 'service' }
    end

    trait :spare_part do
      kind { 'spare_part' }
    end

    factory :featured_product_category do
      feature_accounting { true }

      ignore do
        feature_types_count { 1 }
      end

      after(:create) do |product_category, evaluator|
        product_category.update_attribute :feature_type_ids, [create(:feature_type).id]
      end
    end
  end
end
