FactoryBot.define do
  factory :top_salable do
    salable
    position { 1 }
    color { "MyString" }
  end
end
