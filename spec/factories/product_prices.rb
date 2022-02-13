FactoryBot.define do
  factory :product_price do
    product
    price_type
    date { Time.current }
    value { '1000' }
  end
end
