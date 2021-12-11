require 'rails_helper'

describe ScheduleDay do

  context 'with valid attributes' do

    before :each do
      @schedule_day = ScheduleDay.create user: create(:user), day: 1, hours: '10,11,12,13,14,15,16,17,18'
    end

    it 'should return hours_array' do
      @schedule_day.hours_array.should eq(%w[10 11 12 13 14 15 16 17 18])
    end

    it 'should return begin_of_work' do
      @schedule_day.begin_of_work.should eq(Time.current.change(hour: 10, min: 0, sec: 0))
    end

    it 'should return end_of_work' do
      @schedule_day.end_of_work.should eq(Time.current.change(hour: 18, min: 0, sec: 0))
    end

    it 'should return begin_of_work for given time' do
      time = Time.new 2013, 7, 7, 13, 45
      @schedule_day.begin_of_work(time).should eq(time.change(hour: 10, min: 0, sec: 0))
    end

    it 'should return end_of_work for given time' do
      time = Time.new 2013, 7, 7, 13, 45
      @schedule_day.end_of_work(time).should eq(time.change(hour: 18, min: 0, sec: 0))
    end

  end

  context 'with invalid attributes' do

    it 'should return empty hours_array if no hours present' do
      @schedule_day = ScheduleDay.create user: create(:user), day: 1, hours: nil
      @schedule_day.hours_array.should eq([])
    end

  end

end
