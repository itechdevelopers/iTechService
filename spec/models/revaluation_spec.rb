require 'rails_helper'

describe Revaluation do

  it 'is valid with valid attributes' do
    revaluation = build :revaluation
    expect(revaluation).to be_valid
  end

end
