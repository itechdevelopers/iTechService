FactoryBot.define do
  factory :device_type, aliases: [:valid_device_type] do
    sequence(:name) {|n| "Device type #{n}"}
    
    factory :invalid_device_type do
      name { nil }
    end
  end
end
