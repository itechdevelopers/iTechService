FactoryBot.define do
  factory :salary do
    user
    amount { 10000 }
    is_prepayment { false }
    issued_at { Time.current }

    factory :prepayment do
      is_prepayment { true }
      amount { 1000 }
    end
  end
end
