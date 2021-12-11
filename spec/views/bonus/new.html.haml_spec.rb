require 'rails_helper'

describe "bonus/new" do
  before(:each) do
    assign(:bonu, stub_model(Bonu,
      :bonus_type => nil,
      :comment => "MyText"
    ).as_new_record)
  end

  it "renders new bonu form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", bonus_path, "post" do
      assert_select "input#bonu_bonus_type[name=?]", "bonu[bonus_type]"
      assert_select "textarea#bonu_comment[name=?]", "bonu[comment]"
    end
  end
end
