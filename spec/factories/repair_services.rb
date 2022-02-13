FactoryBot.define do
  factory :repair_service do
    repair_group
    sequence(:name) { |n| "Repair service #{n}" }
    price { 1000.0 }
  end
end
