require 'rails_helper'

describe "departments/show" do
  before(:each) do
    @department = assign(:department, stub_model(Department,
      :name => "Name",
      :role => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
    rendered.should match(/1/)
  end
end
