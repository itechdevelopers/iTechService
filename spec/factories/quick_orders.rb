FactoryBot.define do
  factory :quick_order do
    user
    number { 1 }
    client_name { "MyString" }
    contact_phone { "MyString" }
    comment { "MyText" }
  end
end
