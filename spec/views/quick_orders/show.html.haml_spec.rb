require 'rails_helper'

describe "quick_orders/show" do
  before(:each) do
    @quick_order = assign(:quick_order, stub_model(QuickOrder,
      :number => 1,
      :user => nil,
      :client_name => "Client Name",
      :contact_phone => "Contact Phone",
      :comment => "MyText"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    rendered.should match(//)
    rendered.should match(/Client Name/)
    rendered.should match(/Contact Phone/)
    rendered.should match(/MyText/)
  end
end
