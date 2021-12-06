require 'rails_helper'

describe "top_salables/new" do
  before(:each) do
    assign(:top_salable, stub_model(TopSalable,
      :salable => nil,
      :position => 1,
      :color => "MyString"
    ).as_new_record)
  end

  it "renders new top_salable form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", top_salables_path, "post" do
      assert_select "input#top_salable_salable[name=?]", "top_salable[salable]"
      assert_select "input#top_salable_position[name=?]", "top_salable[position]"
      assert_select "input#top_salable_color[name=?]", "top_salable[color]"
    end
  end
end
