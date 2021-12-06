require 'rails_helper'

describe "discounts/new" do
  before(:each) do
    assign(:discount, stub_model(Discount,
      :value => 1,
      :limit => 1
    ).as_new_record)
  end

  it "renders new discount form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", discounts_path, "post" do
      assert_select "input#discount_value[name=?]", "discount[value]"
      assert_select "input#discount_limit[name=?]", "discount[limit]"
    end
  end
end
