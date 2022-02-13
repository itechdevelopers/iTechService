FactoryBot.define do
  factory :feature_type do
    sequence(:name) { |n| "Feature Type #{n}" }
    kind { 'other' }

    trait :imei do
      kind { 'imei' }
    end

    trait :serial_number do
      kind { 'serial_number' }
    end
  end
end
