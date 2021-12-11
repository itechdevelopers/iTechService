require 'rails_helper'

describe "repair_groups/index" do
  before(:each) do
    assign(:repair_groups, [
      stub_model(RepairGroup,
        :name => "Name",
        :ancestry => "Ancestry"
      ),
      stub_model(RepairGroup,
        :name => "Name",
        :ancestry => "Ancestry"
      )
    ])
  end

  it "renders a list of repair_groups" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "Ancestry".to_s, :count => 2
  end
end
