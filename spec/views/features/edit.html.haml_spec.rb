require 'rails_helper'

describe "features/edit" do
  before(:each) do
    @feature = assign(:feature, stub_model(Feature,
      :feature_type => nil,
      :product => nil,
      :value => nil
    ))
  end

  it "renders the edit feature form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", feature_path(@feature), "post" do
      assert_select "input#feature_feature_type[name=?]", "feature[feature_type]"
      assert_select "input#feature_product[name=?]", "feature[product]"
      assert_select "input#feature_value[name=?]", "feature[value]"
    end
  end
end
