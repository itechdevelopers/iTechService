require 'rails_helper'

describe "case_colors/new" do
  before(:each) do
    assign(:case_color, stub_model(CaseColor,
      :name => "MyString",
      :color => "MyString"
    ).as_new_record)
  end

  it "renders new case_color form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", case_colors_path, "post" do
      assert_select "input#case_color_name[name=?]", "case_color[name]"
      assert_select "input#case_color_color[name=?]", "case_color[color]"
    end
  end
end
