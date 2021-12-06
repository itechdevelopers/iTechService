require 'rails_helper'

describe "price_types/edit" do
  before(:each) do
    @price_type = assign(:price_type, stub_model(PriceType,
      :name => "MyString"
    ))
  end

  it "renders the edit price_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", price_type_path(@price_type), "post" do
      assert_select "input#price_type_name[name=?]", "price_type[name]"
    end
  end
end
