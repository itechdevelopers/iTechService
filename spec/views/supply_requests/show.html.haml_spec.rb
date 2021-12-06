require 'rails_helper'

describe "supply_requests/show" do
  before(:each) do
    @supply_request = assign(:supply_request, stub_model(SupplyRequest,
      :user => nil,
      :status => "Status"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Status/)
  end
end
