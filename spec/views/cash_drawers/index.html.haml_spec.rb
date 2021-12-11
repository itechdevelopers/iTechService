require 'rails_helper'

describe "cash_drawers/index" do
  before(:each) do
    assign(:cash_drawers, [
      stub_model(CashDrawer,
        :name => 1,
        :department => nil
      ),
      stub_model(CashDrawer,
        :name => 1,
        :department => nil
      )
    ])
  end

  it "renders a list of cash_drawers" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
  end
end
