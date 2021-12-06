require 'rails_helper'

describe RepairPart do

  it 'is valid whith valid attributes' do
    repair_part = build :repair_part
    expect(repair_part).to be_valid
  end

end
