require 'rails_helper'

describe "bonus_types/index" do
  before(:each) do
    assign(:bonus_types, [
      stub_model(BonusType,
        :name => "Name"
      ),
      stub_model(BonusType,
        :name => "Name"
      )
    ])
  end

  it "renders a list of bonus_types" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
