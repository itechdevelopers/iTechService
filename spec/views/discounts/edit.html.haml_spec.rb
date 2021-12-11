require 'rails_helper'

describe "discounts/edit" do
  before(:each) do
    @discount = assign(:discount, stub_model(Discount,
      :value => 1,
      :limit => 1
    ))
  end

  it "renders the edit discount form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", discount_path(@discount), "post" do
      assert_select "input#discount_value[name=?]", "discount[value]"
      assert_select "input#discount_limit[name=?]", "discount[limit]"
    end
  end
end
