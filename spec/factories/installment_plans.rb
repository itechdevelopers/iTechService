FactoryBot.define do
  factory :installment_plan do
    user
    cost { 1 }
    issued_at { "2013-07-30" }
  end
end
