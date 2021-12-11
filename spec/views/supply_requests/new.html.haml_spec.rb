require 'rails_helper'

describe "supply_requests/new" do
  before(:each) do
    assign(:supply_request, stub_model(SupplyRequest,
      :user => nil,
      :status => "MyString"
    ).as_new_record)
  end

  it "renders new supply_request form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", supply_requests_path, "post" do
      assert_select "input#supply_request_user[name=?]", "supply_request[user]"
      assert_select "input#supply_request_status[name=?]", "supply_request[status]"
    end
  end
end
