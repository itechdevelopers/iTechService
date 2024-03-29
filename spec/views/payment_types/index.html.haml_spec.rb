require 'rails_helper'

describe "payment_types/index" do
  before(:each) do
    assign(:payment_types, [
      stub_model(PaymentType,
        :name => "Name",
        :kind => 1
      ),
      stub_model(PaymentType,
        :name => "Name",
        :kind => 1
      )
    ])
  end

  it "renders a list of payment_types" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
