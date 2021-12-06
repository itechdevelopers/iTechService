require 'rails_helper'

describe "timesheet_days/new" do
  before(:each) do
    assign(:timesheet_day, stub_model(TimesheetDay,
      :user => nil,
      :status => "MyString",
      :work_mins => 1
    ).as_new_record)
  end

  it "renders new timesheet_day form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", timesheet_days_path, "post" do
      assert_select "input#timesheet_day_user[name=?]", "timesheet_day[user]"
      assert_select "input#timesheet_day_status[name=?]", "timesheet_day[status]"
      assert_select "input#timesheet_day_work_mins[name=?]", "timesheet_day[work_mins]"
    end
  end
end
