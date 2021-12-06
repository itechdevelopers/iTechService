require 'rails_helper'

describe StoreItem do

  it { should belong_to :item }
  it { should belong_to :store }
  it { should validate_presence_of :item }
  it { should validate_presence_of :store }
  it { should validate_presence_of :quantity }
  it { should validate_uniqueness_of(:item_id).scoped_to(:store_id) }

  it 'should be valid with valid attributes' do
    store_item = build :store_item
    store_item.should be_valid
  end

  it 'should increase quantity by given amount' do
    store_item = create :store_item, quantity: 0
    store_item.add 3
    store_item.quantity.should be 3
  end

  it 'should decrease quantity by given amount' do
    store_item = create :store_item, quantity: 5
    store_item.dec 3
    store_item.quantity.should be 2
  end

  it 'should move given amount to given store' do
    store_item = create :store_item, quantity: 5
    dst_store = create :store
    store_item.move_to dst_store, 2
    store_item.quantity.should be 3
    StoreItem.find_by_item_id_and_store_id(store_item.item_id, dst_store.id).quantity.should be 2
  end

  it 'should not create more than one store_item with same item_id and store_id' do
    store_item1 = create :store_item
    store_item2 = build :store_item, item_id: store_item1.item_id, store_id: store_item1.store_id
    store_item2.should_not be_valid
  end

  context 'featured' do

    before :each do
      @store_item = create :store_item, :featured
    end

    it 'should be valid with valid attributes' do
      store_item = build :store_item, :featured
      store_item.should be_valid
    end

    it 'should not increase quantity' do
      @store_item.add 2
      @store_item.quantity.should be 0
    end

    it 'should not descrease quantity' do
      @store_item.dec 2
      @store_item.quantity.should be 0
    end

    it 'should move item to given store' do
      dst_store = create :store
      @store_item.move_to dst_store
      @store_item.store_id.should be dst_store.id
    end

  end

end
