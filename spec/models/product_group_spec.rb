require 'rails_helper'

describe ProductGroup do

  it 'is valid with valid attributes' do
    product_group = build :product_group
    expect(product_group).to be_valid
  end

  context 'feature accounted' do

    it 'is valid with valid attributes' do
      product_group = create :featured_product_group
      expect(product_group).to be_valid
      expect(product_group.feature_accounting).to be_true
    end

  end

end
