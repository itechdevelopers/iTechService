require 'rails_helper'

describe "feature_values/index" do
  before(:each) do
    assign(:feature_values, [
      stub_model(FeatureValue,
        :feature_type => nil,
        :name => "Name"
      ),
      stub_model(FeatureValue,
        :feature_type => nil,
        :name => "Name"
      )
    ])
  end

  it "renders a list of feature_values" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
