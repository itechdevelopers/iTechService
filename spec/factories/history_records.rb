FactoryBot.define do
  factory :history_record do
    user
    column_name { "MyString" }
    column_type { "MyString" }
    old_value { "MyString" }
    new_value { "MyString" }
    deleted_at { "2012-11-22 16:48:53" }
  end
end
