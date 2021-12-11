require 'rails_helper'

describe "supplies/edit" do
  before(:each) do
    @supply = assign(:supply, stub_model(Supply,
      :supply_report => nil,
      :supply_category => nil,
      :name => "",
      :quantity => 1,
      :cost => "9.99"
    ))
  end

  it "renders the edit supply form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", supply_path(@supply), "post" do
      assert_select "input#supply_supply_report[name=?]", "supply[supply_report]"
      assert_select "input#supply_supply_category[name=?]", "supply[supply_category]"
      assert_select "input#supply_name[name=?]", "supply[name]"
      assert_select "input#supply_quantity[name=?]", "supply[quantity]"
      assert_select "input#supply_cost[name=?]", "supply[cost]"
    end
  end
end
