FactoryBot.define do
  factory :task do
    name { 'Some task' }
    duration { 10 }
    cost { 10 }
    priority { 0 }
    location
    product

    trait(:repair) do
      role { 'technician' }
    end

    trait(:important) do
      priority { 6 }
    end
  end
end
