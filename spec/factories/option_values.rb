FactoryBot.define do
  factory :option_value do
    option_type { nil }
    name { "MyString" }
    code { "MyString" }
    position { 1 }
  end
end
