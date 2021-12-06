require 'rails_helper'

describe "repair_services/index" do
  before(:each) do
    assign(:repair_services, [
      stub_model(RepairService,
        :repair_group => nil,
        :name => "Name",
        :price => "9.99"
      ),
      stub_model(RepairService,
        :repair_group => nil,
        :name => "Name",
        :price => "9.99"
      )
    ])
  end

  it "renders a list of repair_services" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "9.99".to_s, :count => 2
  end
end
