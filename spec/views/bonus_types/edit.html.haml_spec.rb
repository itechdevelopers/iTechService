require 'rails_helper'

describe "bonus_types/edit" do
  before(:each) do
    @bonus_type = assign(:bonus_type, stub_model(BonusType,
      :name => "MyString"
    ))
  end

  it "renders the edit bonus_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", bonus_type_path(@bonus_type), "post" do
      assert_select "input#bonus_type_name[name=?]", "bonus_type[name]"
    end
  end
end
