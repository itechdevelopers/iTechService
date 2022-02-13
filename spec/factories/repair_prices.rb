FactoryBot.define do
  factory :repair_price do
    repair_service
    department
    value { 9.99 }
  end
end
