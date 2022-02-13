FactoryBot.define do
  factory :repair_group do
    sequence(:name) { |n| "Repair group #{n}" }
    ancestry { nil }
  end
end
