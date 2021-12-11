require 'rails_helper'

describe "settings/show" do
  before(:each) do
    @setting = assign(:setting, stub_model(Setting,
      :name => "Name",
      :presentation => "Presentation",
      :value => "Value",
      :value_type => "Value Type"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
    rendered.should match(/Presentation/)
    rendered.should match(/Value/)
    rendered.should match(/Value Type/)
  end
end
