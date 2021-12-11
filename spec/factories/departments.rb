# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :department do
    name "MyString"
    code '1234'
    url 'url'
    role 1

    association :city
    association :brand
  end
end
