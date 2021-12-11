require 'rails_helper'

describe FeatureType do

  it 'is valid with valid attributes' do
    feature_type = build :feature_type
    expect(feature_type).to be_valid
  end

end
