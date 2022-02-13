FactoryBot.define do
  factory :comment do
    user
    content { "MyText" }
  end
end
