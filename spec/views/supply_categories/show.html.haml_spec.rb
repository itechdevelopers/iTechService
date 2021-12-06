require 'rails_helper'

describe "supply_categories/show" do
  before(:each) do
    @supply_category = assign(:supply_category, stub_model(SupplyCategory,
      :name => "Name",
      :ancestry => "Ancestry"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
    rendered.should match(/Ancestry/)
  end
end
