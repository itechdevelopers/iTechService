FactoryBot.define do
  factory :feature do
    feature_type
    item
    value { '1' }

    trait :imei do
      association :feature_type, :imei, factory: :feature_type
    end

    trait :serial_number do
      association :feature_type, :serial_number, factory: :feature_type
    end
  end
end
