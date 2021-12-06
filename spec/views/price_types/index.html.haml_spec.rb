require 'rails_helper'

describe "price_types/index" do
  before(:each) do
    assign(:price_types, [
      stub_model(PriceType,
        :name => "Name"
      ),
      stub_model(PriceType,
        :name => "Name"
      )
    ])
  end

  it "renders a list of price_types" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
