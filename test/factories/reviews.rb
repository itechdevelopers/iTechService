FactoryGirl.define do
  factory :review do
    client nil
    service_job nil
    value 1
    content "MyText"
    token "MyString"
  end
end
