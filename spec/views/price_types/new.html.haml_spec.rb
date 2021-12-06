require 'rails_helper'

describe "price_types/new" do
  before(:each) do
    assign(:price_type, stub_model(PriceType,
      :name => "MyString"
    ).as_new_record)
  end

  it "renders new price_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", price_types_path, "post" do
      assert_select "input#price_type_name[name=?]", "price_type[name]"
    end
  end
end
