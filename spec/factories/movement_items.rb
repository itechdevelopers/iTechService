FactoryBot.define do
  factory :movement_item do
    movement_act
    item
    quantity { 1 }
  end
end
