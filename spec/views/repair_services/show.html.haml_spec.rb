require 'rails_helper'

describe "repair_services/show" do
  before(:each) do
    @repair_service = assign(:repair_service, stub_model(RepairService,
      :repair_group => nil,
      :name => "Name",
      :price => "9.99"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Name/)
    rendered.should match(/9.99/)
  end
end
