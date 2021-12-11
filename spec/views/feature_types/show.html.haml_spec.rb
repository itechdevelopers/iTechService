require 'rails_helper'

describe "feature_types/show" do
  before(:each) do
    @feature_type = assign(:feature_type, stub_model(FeatureType,
      :name => "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
  end
end
