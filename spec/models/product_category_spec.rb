require 'rails_helper'

describe ProductCategory do

  it 'should be valid with valid attributes' do
    product_category = build :product_category
    expect(product_category).to be_valid
  end

  context 'feature accounting' do

    it 'should create product_category with feature_types' do
      product_category = create :featured_product_category
      expect(product_category.feature_types.length).to be > 0
      expect(product_category.feature_accounting).to be_true
    end

    it 'should set "feature_accounting" to true if "features_types" present' do
      product_category = create :featured_product_category
      product_category.update_attributes feature_type_ids: [create(:feature_type).id]
      expect(product_category.feature_accounting).to be_true
    end

    it 'should set "feature_accounting" to false if no "features_types" present' do
      product_category = create :product_category
      product_category.update_attributes feature_type_ids: []
      expect(product_category.feature_accounting).to be_false
    end

  end

end
