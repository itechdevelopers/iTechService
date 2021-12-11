require 'rails_helper'

describe "repair_groups/new" do
  before(:each) do
    assign(:repair_group, stub_model(RepairGroup,
      :name => "MyString",
      :ancestry => "MyString"
    ).as_new_record)
  end

  it "renders new repair_group form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", repair_groups_path, "post" do
      assert_select "input#repair_group_name[name=?]", "repair_group[name]"
      assert_select "input#repair_group_ancestry[name=?]", "repair_group[ancestry]"
    end
  end
end
