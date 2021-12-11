require 'rails_helper'

describe "bonus_types/new" do
  before(:each) do
    assign(:bonus_type, stub_model(BonusType,
      :name => "MyString"
    ).as_new_record)
  end

  it "renders new bonus_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", bonus_types_path, "post" do
      assert_select "input#bonus_type_name[name=?]", "bonus_type[name]"
    end
  end
end
