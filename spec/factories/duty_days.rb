FactoryBot.define do
  factory :duty_day do
    user
    day { '2012-12-14' }
    kind { 'kitchen' }
  end
end
