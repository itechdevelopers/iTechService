FactoryBot.define do
  factory :message do
    user
    recipient { nil }
    content { "MyString" }
  end
end
