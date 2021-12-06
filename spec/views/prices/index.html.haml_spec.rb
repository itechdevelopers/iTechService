require 'rails_helper'

describe "prices/index" do
  before(:each) do
    assign(:prices, [
      stub_model(Price,
        :file => "File"
      ),
      stub_model(Price,
        :file => "File"
      )
    ])
  end

  it "renders a list of prices" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "File".to_s, :count => 2
  end
end
