FactoryBot.define do
  factory :payment do
    payment_type
    value { "9.99" }
    bank
  end
end
