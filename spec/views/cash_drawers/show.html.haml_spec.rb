require 'rails_helper'

describe "cash_drawers/show" do
  before(:each) do
    @cash_drawer = assign(:cash_drawer, stub_model(CashDrawer,
      :name => 1,
      :department => nil
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    rendered.should match(//)
  end
end
