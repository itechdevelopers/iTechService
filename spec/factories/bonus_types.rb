FactoryBot.define do
  factory :bonus_type do
    sequence(:name) { |n| "Bonus type #{n}" }
  end
end
