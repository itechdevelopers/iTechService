require 'rails_helper'

describe ClientCharacteristic do

  it 'is valid with valid attributes' do
    build(:client_characteristic).should be_valid
  end

end
