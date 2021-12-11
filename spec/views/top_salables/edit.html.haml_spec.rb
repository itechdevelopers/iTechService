require 'rails_helper'

describe "top_salables/edit" do
  before(:each) do
    @top_salable = assign(:top_salable, stub_model(TopSalable,
      :salable => nil,
      :position => 1,
      :color => "MyString"
    ))
  end

  it "renders the edit top_salable form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", top_salable_path(@top_salable), "post" do
      assert_select "input#top_salable_salable[name=?]", "top_salable[salable]"
      assert_select "input#top_salable_position[name=?]", "top_salable[position]"
      assert_select "input#top_salable_color[name=?]", "top_salable[color]"
    end
  end
end
