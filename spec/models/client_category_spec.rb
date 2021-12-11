require 'rails_helper'

describe ClientCategory do

  it 'is valid with valid attributes' do
    build(:client_category).should be_valid
  end

end
