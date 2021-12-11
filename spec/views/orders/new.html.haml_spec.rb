require 'rails_helper'

describe "orders/new" do
  before(:each) do
    assign(:order, stub_model(Order,
      :customer => nil,
      :object_kind => "MyString",
      :object => "MyString",
      :comment => "MyText",
      :status => "MyString"
    ).as_new_record)
  end

  it "renders new order form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => orders_path, :method => "post" do
      assert_select "input#order_customer", :name => "order[customer]"
      assert_select "input#order_object_kind", :name => "order[object_kind]"
      assert_select "input#order_object", :name => "order[object]"
      assert_select "textarea#order_comment", :name => "order[comment]"
      assert_select "input#order_status", :name => "order[status]"
    end
  end
end
