FactoryBot.define do
  factory :karma do
    user
    good { true }
    comment { 'Comment' }

    trait :bad do
      good { false }
    end
  end
end
