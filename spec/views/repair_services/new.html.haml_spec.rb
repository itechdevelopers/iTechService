require 'rails_helper'

describe "repair_services/new" do
  before(:each) do
    assign(:repair_service, stub_model(RepairService,
      :repair_group => nil,
      :name => "MyString",
      :price => "9.99"
    ).as_new_record)
  end

  it "renders new repair_service form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", repair_services_path, "post" do
      assert_select "input#repair_service_repair_group[name=?]", "repair_service[repair_group]"
      assert_select "input#repair_service_name[name=?]", "repair_service[name]"
      assert_select "input#repair_service_price[name=?]", "repair_service[price]"
    end
  end
end
