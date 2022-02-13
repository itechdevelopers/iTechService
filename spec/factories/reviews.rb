FactoryBot.define do
  factory :review do
    client
    service_job
    value { 1 }
    content { "MyText" }
    token { "MyString" }
  end
end
