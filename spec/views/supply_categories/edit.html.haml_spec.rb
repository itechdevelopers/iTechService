require 'rails_helper'

describe "supply_categories/edit" do
  before(:each) do
    @supply_category = assign(:supply_category, stub_model(SupplyCategory,
      :name => "MyString",
      :ancestry => "MyString"
    ))
  end

  it "renders the edit supply_category form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", supply_category_path(@supply_category), "post" do
      assert_select "input#supply_category_name[name=?]", "supply_category[name]"
      assert_select "input#supply_category_ancestry[name=?]", "supply_category[ancestry]"
    end
  end
end
