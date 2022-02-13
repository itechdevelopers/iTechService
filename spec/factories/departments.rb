FactoryBot.define do
  factory :department do
    name { "MyString" }
    code { '1234' }
    url { 'url' }
    role { 1 }

    association :city
    association :brand
  end
end
