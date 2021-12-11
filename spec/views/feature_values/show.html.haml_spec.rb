require 'rails_helper'

describe "feature_values/show" do
  before(:each) do
    @feature_value = assign(:feature_value, stub_model(FeatureValue,
      :feature_type => nil,
      :name => "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Name/)
  end
end
