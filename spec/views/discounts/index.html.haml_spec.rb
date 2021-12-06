require 'rails_helper'

describe "discounts/index" do
  before(:each) do
    assign(:discounts, [
      stub_model(Discount,
        :value => 1,
        :limit => 2
      ),
      stub_model(Discount,
        :value => 1,
        :limit => 2
      )
    ])
  end

  it "renders a list of discounts" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => 2.to_s, :count => 2
  end
end
