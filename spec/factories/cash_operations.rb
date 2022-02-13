FactoryBot.define do
  factory :cash_operation do
    cash_shift { nil }
    user { nil }
    is_out { false }
    value { "9.99" }
  end
end
