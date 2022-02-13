FactoryBot.define do
  
  factory :client, aliases: [:valid_client] do
    name { 'James Bond' }
    phone_number
    full_phone_number

  end

  sequence :phone_number do |n|
    "234567#{n}"
  end

  sequence :full_phone_number do |n|
    "7234567890#{n}"
  end
  
end
