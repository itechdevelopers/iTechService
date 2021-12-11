require 'rails_helper'

describe DutyDay do

  it 'should have a kind attribute' do
    @duty_day = DutyDay.new
    @duty_day.should respond_to(:kind)
  end

  context 'scopes' do

    it 'should have a kitchen scope' do
      @duty_days = DutyDay.kitchen
      @duty_days.all? do |duty_day|
        duty_day.kind.should eq('kitchen')
      end
    end

    it 'should have a salesroom scope' do
      @duty_days = DutyDay.salesroom
      @duty_days.all? do |duty_day|
        duty_day.kind.should eq('salesroom')
      end
    end

  end

end
