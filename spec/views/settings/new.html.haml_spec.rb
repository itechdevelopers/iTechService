require 'rails_helper'

describe "settings/new" do
  before(:each) do
    assign(:setting, stub_model(Setting,
      :name => "MyString",
      :presentation => "MyString",
      :value => "MyString",
      :value_type => "MyString"
    ).as_new_record)
  end

  it "renders new setting form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => settings_path, :method => "post" do
      assert_select "input#setting_name", :name => "setting[name]"
      assert_select "input#setting_presentation", :name => "setting[presentation]"
      assert_select "input#setting_value", :name => "setting[value]"
      assert_select "input#setting_value_type", :name => "setting[value_type]"
    end
  end
end
