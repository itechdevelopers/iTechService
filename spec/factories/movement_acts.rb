FactoryBot.define do
  factory :movement_act do
    status { 0 }
    date { Time.current }
    store
    association :dst_store, factory: :store
    user
  end
end
