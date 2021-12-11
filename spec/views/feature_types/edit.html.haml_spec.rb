require 'rails_helper'

describe "feature_types/edit" do
  before(:each) do
    @feature_type = assign(:feature_type, stub_model(FeatureType,
      :name => "MyString"
    ))
  end

  it "renders the edit feature_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", feature_type_path(@feature_type), "post" do
      assert_select "input#feature_type_name[name=?]", "feature_type[name]"
    end
  end
end
