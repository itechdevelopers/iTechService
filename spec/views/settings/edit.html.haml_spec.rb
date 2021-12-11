require 'rails_helper'

describe "settings/edit" do
  before(:each) do
    @setting = assign(:setting, stub_model(Setting,
      :name => "MyString",
      :presentation => "MyString",
      :value => "MyString",
      :value_type => "MyString"
    ))
  end

  it "renders the edit setting form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => settings_path(@setting), :method => "post" do
      assert_select "input#setting_name", :name => "setting[name]"
      assert_select "input#setting_presentation", :name => "setting[presentation]"
      assert_select "input#setting_value", :name => "setting[value]"
      assert_select "input#setting_value_type", :name => "setting[value_type]"
    end
  end
end
