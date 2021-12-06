require 'rails_helper'

describe BonusType do
  let(:bonus_type) { create :bonus_type }

  it 'is valid with valid attributes' do
    build(:bonus_type).should be_valid
  end

end
