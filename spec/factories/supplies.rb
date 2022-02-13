FactoryBot.define do
  factory :supply do
    supply_report
    supply_category
    name { "Name" }
    quantity { 1 }
    cost { 9.99 }
  end
end
