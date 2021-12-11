require 'rails_helper'

describe Purchase do

  it { should belong_to :contractor }
  it { should belong_to :store }
  it { should have_many :batches }
  it { should accept_nested_attributes_for :batches }
  it { should validate_presence_of :date }
  it { should validate_presence_of :status }
  it { should validate_presence_of :store }
  it { should validate_presence_of :contractor }
  it { should ensure_inclusion_of(:status).in_array(Document::STATUSES.keys) }

  it 'is valid with valid attributes' do
    purchase = create :purchase
    expect(purchase).to be_true
  end

  context 'posting' do

    it 'should create "store_items" with valid quantity for products without features after posting' do
      item = create(:item)
      purchase = create :purchase, batches_attributes: {'1' => {item_id: item.id, price: 1000, quantity: 3}}
      purchase.post
      expect(item.store_items.count).to eq 1
      expect(item.store_items.in_store(purchase.store_id).count).to eq 1
      expect(item.store_items.in_store(purchase.store_id).first.quantity).to eq 3
    end

    it 'should create "store_items" with valid quantity for products with features after posting' do
      item = create(:featured_item)
      purchase = create :purchase, batches_attributes: {'1' => {item_id: item.id, price: 1000, quantity: 1}}
      purchase.post
      expect(item.store_items.count).to eq 1
      expect(item.store_items.in_store(purchase.store_id).count).to eq 1
      expect(item.quantity_in_store(purchase.store_id)).to eq 1
    end

    it 'should create "product_prices" for products after posting' do
      item = create(:item)
      purchase = create :purchase, batches_attributes: {'1' => {item_id: item.id, price: 1000, quantity: 3}}
      purchase.post
      expect(item.prices.count).to eq 1
      expect(item.prices.first.value).to eq 1000
    end

    it 'should not post if featured store_item already present' do
      item = create :featured_item
      store1 = create :store
      store2 = create :store
      store_item = create :store_item, item: item, store: store2, quantity: 1
      purchase = create :purchase, store: store1, batches_attributes: {'1' => {item_id: item.id, price: 1000, quantity: 1}}
      purchase.post
      purchase.status.should eq 0
      store_item.store.should eq store2
    end

  end

end
