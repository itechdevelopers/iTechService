require 'rails_helper'

describe "supply_categories/new" do
  before(:each) do
    assign(:supply_category, stub_model(SupplyCategory,
      :name => "MyString",
      :ancestry => "MyString"
    ).as_new_record)
  end

  it "renders new supply_category form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", supply_categories_path, "post" do
      assert_select "input#supply_category_name[name=?]", "supply_category[name]"
      assert_select "input#supply_category_ancestry[name=?]", "supply_category[ancestry]"
    end
  end
end
