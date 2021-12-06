require 'rails_helper'

describe MovementItem do

  it { should belong_to :movement_act }
  it { should belong_to :item }
  it { should validate_presence_of :movement_act }
  it { should validate_presence_of :item }
  it { should validate_presence_of :quantity }
  it { should validate_numericality_of(:quantity).only_integer.is_greater_than(0) }

  it 'should be valid with valid attributes' do
    movement_item = build :movement_item
    movement_item.should be_valid
  end

end
