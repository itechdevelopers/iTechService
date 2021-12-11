require 'rails_helper'

describe "cash_drawers/edit" do
  before(:each) do
    @cash_drawer = assign(:cash_drawer, stub_model(CashDrawer,
      :name => 1,
      :department => nil
    ))
  end

  it "renders the edit cash_drawer form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", cash_drawer_path(@cash_drawer), "post" do
      assert_select "input#cash_drawer_name[name=?]", "cash_drawer[name]"
      assert_select "input#cash_drawer_department[name=?]", "cash_drawer[department]"
    end
  end
end
