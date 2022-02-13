FactoryBot.define do
  factory :sale do
    status { 0 }
    date { Time.current }
    user
    client
    store
    payment_type

    factory :sale_with_items do
      after(:create) do |sale|
        #sale.sale_items.create attributes_for(:sale_item)
        create :sale_item, sale_id: sale.id
      end
    end

    factory :sale_with_featured_items do
      after(:create) do |sale|
        #sale.sale_items.create attributes_for(:featured_sale_item)
        create :featured_sale_item, sale_id: sale.id
      end
    end

  end
end
