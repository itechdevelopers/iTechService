require 'rails_helper'

describe "client_categories/edit" do
  before(:each) do
    @client_category = assign(:client_category, stub_model(ClientCategory,
      :name => "MyString",
      :color => "MyString"
    ))
  end

  it "renders the edit client_category form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", client_category_path(@client_category), "post" do
      assert_select "input#client_category_name[name=?]", "client_category[name]"
      assert_select "input#client_category_color[name=?]", "client_category[color]"
    end
  end
end
