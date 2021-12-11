require 'rails_helper'

describe "timesheet_days/show" do
  before(:each) do
    @timesheet_day = assign(:timesheet_day, stub_model(TimesheetDay,
      :user => nil,
      :status => "Status",
      :work_mins => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Status/)
    rendered.should match(/1/)
  end
end
