require 'rails_helper'

describe "supplies/index" do
  before(:each) do
    assign(:supplies, [
      stub_model(Supply,
        :supply_report => nil,
        :supply_category => nil,
        :name => "",
        :quantity => 1,
        :cost => "9.99"
      ),
      stub_model(Supply,
        :supply_report => nil,
        :supply_category => nil,
        :name => "",
        :quantity => 1,
        :cost => "9.99"
      )
    ])
  end

  it "renders a list of supplies" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "".to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => "9.99".to_s, :count => 2
  end
end
