FactoryBot.define do
  factory :device_note do
    device
    user
    content { "MyText" }
  end
end
