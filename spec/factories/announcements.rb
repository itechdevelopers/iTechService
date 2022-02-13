# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :announcement do
    association :department
    association :user
    active true
    kind 'help'
    content 'Content'
  end
end
