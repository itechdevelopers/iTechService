require 'rails_helper'

describe "purchases/index" do
  before(:each) do
    assign(:purchases, [
      stub_model(Purchase,
        :contractor => nil,
        :store => nil
      ),
      stub_model(Purchase,
        :contractor => nil,
        :store => nil
      )
    ])
  end

  it "renders a list of purchases" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
  end
end
