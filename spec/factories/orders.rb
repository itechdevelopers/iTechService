FactoryBot.define do
  factory :order do
    customer nil
    object_kind { "MyString" }
    object { "MyString" }
    desired_date { "2013-01-12" }
    comment { "MyText" }
    status { "MyString" }
  end
end
