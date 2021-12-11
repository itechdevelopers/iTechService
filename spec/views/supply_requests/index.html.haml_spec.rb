require 'rails_helper'

describe "supply_requests/index" do
  before(:each) do
    assign(:supply_requests, [
      stub_model(SupplyRequest,
        :user => nil,
        :status => "Status"
      ),
      stub_model(SupplyRequest,
        :user => nil,
        :status => "Status"
      )
    ])
  end

  it "renders a list of supply_requests" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Status".to_s, :count => 2
  end
end
