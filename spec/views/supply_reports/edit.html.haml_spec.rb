require 'rails_helper'

describe "supply_reports/edit" do
  before(:each) do
    @supply_report = assign(:supply_report, stub_model(SupplyReport))
  end

  it "renders the edit supply_report form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", supply_report_path(@supply_report), "post" do
    end
  end
end
