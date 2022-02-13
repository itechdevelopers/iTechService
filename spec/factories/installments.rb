FactoryBot.define do
  factory :installment do
    installment_plan
    value { 1 }
    paid_at { "2013-07-30" }
  end
end
