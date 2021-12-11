# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
    sequence(:username) { |n| "User #{n}" }
    role 'software'
    password 'password'
    association :department
    association :location


    factory :user_without_username do
      username nil
    end
    
    factory :user_without_password do
      password nil
    end
  end
  
  trait :admin do
    username 'Admin'
    role 'admin'
  end

  trait :software do
    role 'software'
  end

  trait :media do
    role 'media'
  end

  trait :technician do
    role 'technician'
  end

  trait :marketing do
    role 'marketing'
  end

  trait :programmer do
    role 'programmer'
  end

  trait :supervisor do
    role 'supervisor'
  end

  trait :manager do
    role 'manager'
  end

  trait :superadmin do
    role 'superadmin'
  end
end
