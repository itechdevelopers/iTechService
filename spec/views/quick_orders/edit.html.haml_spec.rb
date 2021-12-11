require 'rails_helper'

describe "quick_orders/edit" do
  before(:each) do
    @quick_order = assign(:quick_order, stub_model(QuickOrder,
      :number => 1,
      :user => nil,
      :client_name => "MyString",
      :contact_phone => "MyString",
      :comment => "MyText"
    ))
  end

  it "renders the edit quick_order form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", quick_order_path(@quick_order), "post" do
      assert_select "input#quick_order_number[name=?]", "quick_order[number]"
      assert_select "input#quick_order_user[name=?]", "quick_order[user]"
      assert_select "input#quick_order_client_name[name=?]", "quick_order[client_name]"
      assert_select "input#quick_order_contact_phone[name=?]", "quick_order[contact_phone]"
      assert_select "textarea#quick_order_comment[name=?]", "quick_order[comment]"
    end
  end
end
