require 'rails_helper'

describe "timesheet_days/index" do
  before(:each) do
    assign(:timesheet_days, [
      stub_model(TimesheetDay,
        :user => nil,
        :status => "Status",
        :work_mins => 1
      ),
      stub_model(TimesheetDay,
        :user => nil,
        :status => "Status",
        :work_mins => 1
      )
    ])
  end

  it "renders a list of timesheet_days" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Status".to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
