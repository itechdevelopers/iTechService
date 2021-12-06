require 'rails_helper'

describe "client_categories/new" do
  before(:each) do
    assign(:client_category, stub_model(ClientCategory,
      :name => "MyString",
      :color => "MyString"
    ).as_new_record)
  end

  it "renders new client_category form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", client_categories_path, "post" do
      assert_select "input#client_category_name[name=?]", "client_category[name]"
      assert_select "input#client_category_color[name=?]", "client_category[color]"
    end
  end
end
