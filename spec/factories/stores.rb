FactoryBot.define do
  factory :store do
    sequence(:name) {|n| "Store #{n}"}
    sequence(:code) {|n| "store_#{n}"}

    factory :store_for_purchase do
      after(:create) do |store|
        store.update_attribute :price_type_ids, [create(:price_type, :purchase).id]
      end
    end

    factory :store_for_retail do
      after(:create) do |store|
        store.update_attribute :price_type_ids, [create(:price_type, :retail).id]
      end
    end
  end
end
