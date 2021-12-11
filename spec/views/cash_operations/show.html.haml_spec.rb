require 'rails_helper'

describe "cash_operations/show" do
  before(:each) do
    @cash_operation = assign(:cash_operation, stub_model(CashOperation,
      :cash_shift => nil,
      :user => nil,
      :is_out => false,
      :value => "9.99"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(/false/)
    rendered.should match(/9.99/)
  end
end
