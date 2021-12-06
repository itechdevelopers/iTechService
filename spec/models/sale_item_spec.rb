require 'rails_helper'

describe SaleItem do

  it 'is valid with valid attributes' do
    sale_item = create :sale_item
    expect(sale_item).to be_valid
  end

end