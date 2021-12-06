require 'rails_helper'

describe "infos/edit" do
  before(:each) do
    @info = assign(:info, stub_model(Info,
      :title => "MyString",
      :content => "MyText"
    ))
  end

  it "renders the edit info form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => infos_path(@info), :method => "post" do
      assert_select "input#info_title", :name => "info[title]"
      assert_select "textarea#info_content", :name => "info[content]"
    end
  end
end
