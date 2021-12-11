require 'rails_helper'

describe TimesheetDay do

  context 'with valid attributes' do

    it 'should convert work_hours to work_mins' do
      user = create :user
      @timesheet_day = TimesheetDay.create user: user, date: '2013-07-01', work_hours: 8
      @timesheet_day.work_mins.should eq(480)
    end

    it 'should return correct actual_work_mins for lateness' do
      time = Time.new 2013, 07, 07, 12, 00
      user = create :user
      user.schedule_days.create day: time.wday, hours: '10,11,12,13,14,15,16,17,18'
      timesheet_day = user.timesheet_days.create status: 'presence_late', date: '2013-07-07', time: '10:45', work_mins: 480
      timesheet_day.actual_work_mins.should eq(435)
    end

    it 'should return correct actual_work_hours for lateness' do
      time = Time.new 2013, 07, 07, 12, 00
      user = create :user
      user.schedule_days.create day: time.wday, hours: '10,11,12,13,14,15,16,17,18'
      timesheet_day = user.timesheet_days.create status: 'presence_late', date: '2013-07-07', time: '10:45', work_mins: 480
      timesheet_day.actual_work_hours.should eq(7.25)
    end

  end

  context 'with invalid attributes' do

    it 'should return 0 for actual_work_mins and actual_work_hours if work_mins is nil' do
      @timesheet_day = create :timesheet_day, work_mins: nil
      @timesheet_day.actual_work_mins.should eq(0)
      @timesheet_day.actual_work_hours.should eq(0)
    end

  end

end
