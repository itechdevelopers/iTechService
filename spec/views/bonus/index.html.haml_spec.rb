require 'rails_helper'

describe "bonus/index" do
  before(:each) do
    assign(:bonus, [
      stub_model(Bonu,
        :bonus_type => nil,
        :comment => "MyText"
      ),
      stub_model(Bonu,
        :bonus_type => nil,
        :comment => "MyText"
      )
    ])
  end

  it "renders a list of bonus" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
