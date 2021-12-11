require 'rails_helper'

describe "orders/index" do
  before(:each) do
    assign(:orders, [
      stub_model(Order,
        :customer => nil,
        :object_kind => "Object Kind",
        :object => "Object",
        :comment => "MyText",
        :status => "Status"
      ),
      stub_model(Order,
        :customer => nil,
        :object_kind => "Object Kind",
        :object => "Object",
        :comment => "MyText",
        :status => "Status"
      )
    ])
  end

  it "renders a list of orders" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Object Kind".to_s, :count => 2
    assert_select "tr>td", :text => "Object".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "Status".to_s, :count => 2
  end
end
