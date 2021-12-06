require 'rails_helper'

describe Client do
  
  it 'is valid with valid attributes' do
    client = build :client
    expect(client).to be_valid
  end
  
  it 'is not valid without "name"' do
    client = build :client_without_name
    client.should_not be_valid
  end
  
  it 'is not valid without "phone number"' do
    client = build :client_without_phone_number
    client.should_not be_valid
  end
  
  describe 'associations' do
    
    it 'should have "devices" attribute' do
      client = create :client
      client.should respond_to :service_jobs
    end

    it 'creates "client_characteristic"' do
      client_category = create :client_category
      client = Client.create attributes_for(:client).merge(client_characteristic_attributes: {client_category_id: client_category.id, comment: 'Comment'})
      client.should be_persisted
      ClientCharacteristic.count.should be 1
    end

  end
  
end
