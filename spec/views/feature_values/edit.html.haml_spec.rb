require 'rails_helper'

describe "feature_values/edit" do
  before(:each) do
    @feature_value = assign(:feature_value, stub_model(FeatureValue,
      :feature_type => nil,
      :name => "MyString"
    ))
  end

  it "renders the edit feature_value form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", feature_value_path(@feature_value), "post" do
      assert_select "input#feature_value_feature_type[name=?]", "feature_value[feature_type]"
      assert_select "input#feature_value_name[name=?]", "feature_value[name]"
    end
  end
end
