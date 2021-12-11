require 'rails_helper'

describe "cash_drawers/new" do
  before(:each) do
    assign(:cash_drawer, stub_model(CashDrawer,
      :name => 1,
      :department => nil
    ).as_new_record)
  end

  it "renders new cash_drawer form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", cash_drawers_path, "post" do
      assert_select "input#cash_drawer_name[name=?]", "cash_drawer[name]"
      assert_select "input#cash_drawer_department[name=?]", "cash_drawer[department]"
    end
  end
end
