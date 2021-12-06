require 'rails_helper'

describe "features/new" do
  before(:each) do
    assign(:feature, stub_model(Feature,
      :feature_type => nil,
      :product => nil,
      :value => nil
    ).as_new_record)
  end

  it "renders new feature form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", features_path, "post" do
      assert_select "input#feature_feature_type[name=?]", "feature[feature_type]"
      assert_select "input#feature_product[name=?]", "feature[product]"
      assert_select "input#feature_value[name=?]", "feature[value]"
    end
  end
end
