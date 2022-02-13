FactoryBot.define do
  factory :repair_part do
    repair_task
    item
    warranty_term { 0 }
  end
end
