require 'rails_helper'

describe "supply_requests/edit" do
  before(:each) do
    @supply_request = assign(:supply_request, stub_model(SupplyRequest,
      :user => nil,
      :status => "MyString"
    ))
  end

  it "renders the edit supply_request form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", supply_request_path(@supply_request), "post" do
      assert_select "input#supply_request_user[name=?]", "supply_request[user]"
      assert_select "input#supply_request_status[name=?]", "supply_request[status]"
    end
  end
end
