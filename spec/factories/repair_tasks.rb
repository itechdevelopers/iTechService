FactoryBot.define do
  factory :repair_task do
    repair_service
    device_task
    price { 1000.0 }
  end
end
