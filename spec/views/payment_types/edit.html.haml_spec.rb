require 'rails_helper'

describe "payment_types/edit" do
  before(:each) do
    @payment_type = assign(:payment_type, stub_model(PaymentType,
      :name => "MyString",
      :kind => 1
    ))
  end

  it "renders the edit payment_type form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", payment_type_path(@payment_type), "post" do
      assert_select "input#payment_type_name[name=?]", "payment_type[name]"
      assert_select "input#payment_type_kind[name=?]", "payment_type[kind]"
    end
  end
end
