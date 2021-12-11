require 'rails_helper'

describe "repair_groups/edit" do
  before(:each) do
    @repair_group = assign(:repair_group, stub_model(RepairGroup,
      :name => "MyString",
      :ancestry => "MyString"
    ))
  end

  it "renders the edit repair_group form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", repair_group_path(@repair_group), "post" do
      assert_select "input#repair_group_name[name=?]", "repair_group[name]"
      assert_select "input#repair_group_ancestry[name=?]", "repair_group[ancestry]"
    end
  end
end
