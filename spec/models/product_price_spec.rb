require 'rails_helper'

describe ProductPrice do

  it 'is valid with valid attributes' do
    product_price = build :product_price
    expect(product_price).to be_valid
  end

end
