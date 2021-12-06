require 'rails_helper'

describe "cash_operations/index" do
  before(:each) do
    assign(:cash_operations, [
      stub_model(CashOperation,
        :cash_shift => nil,
        :user => nil,
        :is_out => false,
        :value => "9.99"
      ),
      stub_model(CashOperation,
        :cash_shift => nil,
        :user => nil,
        :is_out => false,
        :value => "9.99"
      )
    ])
  end

  it "renders a list of cash_operations" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
    assert_select "tr>td", :text => "9.99".to_s, :count => 2
  end
end
