require 'rails_helper'

describe "supply_reports/new" do
  before(:each) do
    assign(:supply_report, stub_model(SupplyReport).as_new_record)
  end

  it "renders new supply_report form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", supply_reports_path, "post" do
    end
  end
end
