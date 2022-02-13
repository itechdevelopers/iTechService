FactoryBot.define do
  factory :location do
    name { 'Name' }
    position { 1 }
    ancestry { nil }

    association :department
  end

  trait :repair do
    name { 'Ремонт' }
  end

  trait :bar do
    name { 'Бар' }
  end

end
