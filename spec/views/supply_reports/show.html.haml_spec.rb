require 'rails_helper'

describe "supply_reports/show" do
  before(:each) do
    @supply_report = assign(:supply_report, stub_model(SupplyReport))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
  end
end
