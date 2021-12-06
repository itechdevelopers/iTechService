require 'rails_helper'

describe "bonus/edit" do
  before(:each) do
    @bonu = assign(:bonu, stub_model(Bonu,
      :bonus_type => nil,
      :comment => "MyText"
    ))
  end

  it "renders the edit bonu form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", bonu_path(@bonu), "post" do
      assert_select "input#bonu_bonus_type[name=?]", "bonu[bonus_type]"
      assert_select "textarea#bonu_comment[name=?]", "bonu[comment]"
    end
  end
end
