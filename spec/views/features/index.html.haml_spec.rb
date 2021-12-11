require 'rails_helper'

describe "features/index" do
  before(:each) do
    assign(:features, [
      stub_model(Feature,
        :feature_type => nil,
        :product => nil,
        :value => nil
      ),
      stub_model(Feature,
        :feature_type => nil,
        :product => nil,
        :value => nil
      )
    ])
  end

  it "renders a list of features" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
  end
end
