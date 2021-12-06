require 'rails_helper'

describe Item do

  it 'is valid with valid attributes' do
    item = build :item
    expect(item).to be_valid
  end

  it 'should be uniq by product' do
    product = create :product
    create :item, product_id: product.id
    item = build :item, product_id: product.id
    expect(item).to_not be_valid
  end

  it 'should generate barcode on create' do
    item = create :item
    expect(item.barcode).to_not be_nil
    expect(item.barcode_num).to start_with('242' + '0'*(9-item.id.to_s.length) + item.id.to_s)
    expect(item.barcode_data).to_not be_nil
  end

  it 'should return "store_item" for given "store"' do
    item = create :item
    store = create :store
    store_item = create :store_item, item: item, store: store
    item.store_item(store).should eq store_item
  end

  it 'should return new "store_item" with "quantity" eq 0 if it absent in given "store"' do
    item = create :item
    store = create :store
    item.store_item(store).quantity.should eq 0
  end

  context 'feature accounting' do

    it 'is valid with valid attributes' do
      item = create :featured_item
      expect(item).to be_valid
      expect(item.feature_accounting).to be_true
    end

    it 'should not be uniq if feature accounting' do
      product = create :featured_product
      create :item, product_id: product.id
      item = build :item, product_id: product.id
      expect(item).to be_valid
    end

    it 'should return "store_item"' do
      item = create :featured_item
      store_item = create :store_item, item: item, quantity: 1
      item.store_item.should eq store_item
    end

  end

end
