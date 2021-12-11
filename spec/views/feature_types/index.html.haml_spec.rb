require 'rails_helper'

describe "feature_types/index" do
  before(:each) do
    assign(:feature_types, [
      stub_model(FeatureType,
        :name => "Name"
      ),
      stub_model(FeatureType,
        :name => "Name"
      )
    ])
  end

  it "renders a list of feature_types" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
