require 'rails_helper'

describe "features/show" do
  before(:each) do
    @feature = assign(:feature, stub_model(Feature,
      :feature_type => nil,
      :product => nil,
      :value => nil
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(//)
  end
end
