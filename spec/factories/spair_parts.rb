FactoryBot.define do
  factory :spare_part do
    repair_service
    item
    quantity { 1 }
    warranty_term { 1 }
  end
end
