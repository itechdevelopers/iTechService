require 'rails_helper'

describe "products/edit" do
  before(:each) do
    @product = assign(:product, stub_model(Product,
      :name => "MyString",
      :code => 1,
      :group_id => nil
    ))
  end

  it "renders the edit product form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", product_path(@product), "post" do
      assert_select "input#product_name[name=?]", "product[name]"
      assert_select "input#product_code[name=?]", "product[code]"
      assert_select "input#product_group_id[name=?]", "product[group_id]"
    end
  end
end
