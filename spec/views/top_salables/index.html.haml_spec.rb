require 'rails_helper'

describe "top_salables/index" do
  before(:each) do
    assign(:top_salables, [
      stub_model(TopSalable,
        :salable => nil,
        :position => 1,
        :color => "Color"
      ),
      stub_model(TopSalable,
        :salable => nil,
        :position => 1,
        :color => "Color"
      )
    ])
  end

  it "renders a list of top_salables" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => "Color".to_s, :count => 2
  end
end
