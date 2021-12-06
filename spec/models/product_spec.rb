require 'rails_helper'

describe Product do

  it 'is valid with valid attributes' do
    product = build :product
    expect(product).to be_valid
  end

  it 'should return "actual_price"' do
    product = create :product
    price_type = create :price_type
    product.prices.create date: Time.current, value: 1000.0, price_type_id: price_type.id
    product.prices.create date: 1.day.ago, value: 2000.0, price_type_id: price_type.id
    expect(product.actual_price(price_type)).to eq(1000.0)
  end

  it 'should create task if product is service' do
    product = create :product, :service
    expect(product.task).to be_an_instance_of(Task)
  end

  it 'should destroy task if product is not service' do
    product = create :product, :service
    product.product_group.update_attribute :is_service, false
    product.save
    expect(product.task.persisted?).to be_false
  end

  context 'feature_accounting' do

    it 'is valid with valid attributes' do
      product = create :featured_product
      expect(product).to be_valid
    end

  end

end
