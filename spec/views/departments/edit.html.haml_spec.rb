require 'rails_helper'

describe "departments/edit" do
  before(:each) do
    @department = assign(:department, stub_model(Department,
      :name => "MyString",
      :role => 1
    ))
  end

  it "renders the edit department form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", department_path(@department), "post" do
      assert_select "input#department_name[name=?]", "department[name]"
      assert_select "input#department_role[name=?]", "department[role]"
    end
  end
end
