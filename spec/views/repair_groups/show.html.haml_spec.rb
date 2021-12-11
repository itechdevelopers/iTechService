require 'rails_helper'

describe "repair_groups/show" do
  before(:each) do
    @repair_group = assign(:repair_group, stub_model(RepairGroup,
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
