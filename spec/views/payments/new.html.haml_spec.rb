require 'rails_helper'

describe "payments/new" do
  before(:each) do
    assign(:payment, stub_model(Payment,
      :payment_type => nil,
      :value => "9.99",
      :bank => nil
    ).as_new_record)
  end

  it "renders new payment form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", payments_path, "post" do
      assert_select "input#payment_payment_type[name=?]", "payment[payment_type]"
      assert_select "input#payment_value[name=?]", "payment[value]"
      assert_select "input#payment_bank[name=?]", "payment[bank]"
    end
  end
end
