require 'rails_helper'

describe PriceType do

  it 'should be valid with valid attributes' do
    price_type = build :price_type
    expect(price_type).to be_valid
  end
  
end
