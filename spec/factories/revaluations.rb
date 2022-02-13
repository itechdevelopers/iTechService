FactoryBot.define do
  factory :revaluation do
    revaluation_act
    product
    price { 1000 }
  end
end
