FactoryBot.define do

  factory :device_task do
    association :device
    association :task
    done { false }
    done_at { nil }
    cost { 100 }
    comment { 'comment' }

    trait :done do
      done { true }
      done_at { Time.current }
    end
    
    trait(:important) { association :task, :important }
    trait(:repair) { association :task, :repair }
  end

end
