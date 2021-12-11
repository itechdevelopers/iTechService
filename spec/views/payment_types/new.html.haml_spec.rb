require 'rails_helper'

describe "payment_types/new" do
  before(:each) do
    assign(:payment_type, stub_model(PaymentType,
      :name => "MyString",
      :kind => 1
    ).as_new_record)
  end

  it "renders new payment_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", payment_types_path, "post" do
      assert_select "input#payment_type_name[name=?]", "payment_type[name]"
      assert_select "input#payment_type_kind[name=?]", "payment_type[kind]"
    end
  end
end
