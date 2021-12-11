require 'rails_helper'

describe "supply_reports/index" do
  before(:each) do
    assign(:supply_reports, [
      stub_model(SupplyReport),
      stub_model(SupplyReport)
    ])
  end

  it "renders a list of supply_reports" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
  end
end
