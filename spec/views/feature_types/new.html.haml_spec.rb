require 'rails_helper'

describe "feature_types/new" do
  before(:each) do
    assign(:feature_type, stub_model(FeatureType,
      :name => "MyString"
    ).as_new_record)
  end

  it "renders new feature_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", feature_types_path, "post" do
      assert_select "input#feature_type_name[name=?]", "feature_type[name]"
    end
  end
end
