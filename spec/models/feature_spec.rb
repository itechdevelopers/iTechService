require 'rails_helper'

describe Feature do

  it 'is valid with valid attributes' do
    feature = build :feature
    expect(feature).to be_valid
  end

  context 'validation' do

    it 'should be invalid with invalid imei length' do
      feature = build :feature, :imei, value: '111'
      expect(feature).to_not be_valid
    end

    it 'should be valid with valid imei length' do
      feature = build :feature, :imei, value: '123456789012345'
      expect(feature).to be_valid
    end

  end

end
