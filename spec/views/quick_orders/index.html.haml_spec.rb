require 'rails_helper'

describe "quick_orders/index" do
  before(:each) do
    assign(:quick_orders, [
      stub_model(QuickOrder,
        :number => 1,
        :user => nil,
        :client_name => "Client Name",
        :contact_phone => "Contact Phone",
        :comment => "MyText"
      ),
      stub_model(QuickOrder,
        :number => 1,
        :user => nil,
        :client_name => "Client Name",
        :contact_phone => "Contact Phone",
        :comment => "MyText"
      )
    ])
  end

  it "renders a list of quick_orders" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Client Name".to_s, :count => 2
    assert_select "tr>td", :text => "Contact Phone".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
