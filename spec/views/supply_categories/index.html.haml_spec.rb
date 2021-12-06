require 'rails_helper'

describe "supply_categories/index" do
  before(:each) do
    assign(:supply_categories, [
      stub_model(SupplyCategory,
        :name => "Name",
        :ancestry => "Ancestry"
      ),
      stub_model(SupplyCategory,
        :name => "Name",
        :ancestry => "Ancestry"
      )
    ])
  end

  it "renders a list of supply_categories" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "Ancestry".to_s, :count => 2
  end
end
