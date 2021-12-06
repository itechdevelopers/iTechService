require 'rails_helper'

describe Sale do

  it { should belong_to :user }
  it { should belong_to :client }
  it { should belong_to :store }
  it { should belong_to :payment_type }
  it { should have_many :sale_items }
  it { should accept_nested_attributes_for :sale_items }
  it { should validate_presence_of :date }
  it { should validate_presence_of :status }
  it { should validate_presence_of :store }
  it { should validate_presence_of :client }
  it { should validate_presence_of :user }
  it { should validate_presence_of :payment_type }
  it { should ensure_inclusion_of(:status).in_array(Document::STATUSES.keys) }

  it 'is valid with valid attributes' do
    sale = build :sale
    expect(sale).to be_valid
  end

  it 'is valid with items' do
    sale = create :sale_with_items
    expect(sale).to be_valid
    expect(sale.sale_items.count).to be > 0
  end

  it 'is valid with featured items' do
    sale = create :sale_with_featured_items
    expect(sale).to be_valid
    expect(sale.sale_items.count).to be > 0
  end

  context 'posting' do

    before :each do
      @store = create :store
      @sale = create :sale, store_id: @store.id
    end

    it 'should decrease quantity of products without features after posting' do
      item = create :item
      StoreItem.create item_id: item.id, store_id: @store.id, quantity: 5
      @sale.sale_items.create item_id: item.id, price: 1000, quantity: 2
      @sale.post
      item.quantity_in_store(@store).should eq 3
    end

    it 'should decrease quantity of products with features after posting' do
      item = create :featured_item
      StoreItem.create item_id: item.id, store_id: @store.id, quantity: 1
      @sale.sale_items.create item_id: item.id, price: 1000, quantity: 1
      @sale.post
      item.quantity_in_store(@store).should eq 0
    end

    it 'should not post if not enough items in store' do
      item = create :item
      StoreItem.create store_id: @store.id, item_id: item.id, quantity: 1
      @sale.sale_items.create item_id: item.id, price: 1000, quantity: 2
      @sale.post
      @sale.status.should eq 0
      item.quantity_in_store(@store).should eq 1
    end

    it 'should not post if there is no item in store' do
      item = create :featured_item
      @sale.sale_items.create item_id: item.id, price: 1000, quantity: 1
      @sale.post
      @sale.status.should eq 0
      item.quantity_in_store(@store).should eq 0
    end

    #it 'should restore quantity of products after unposting' do
    #  sale = create :sale
    #end

  end

end
