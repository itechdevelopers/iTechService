require 'rails_helper'

describe "revaluations/index" do
  before(:each) do
    assign(:revaluations, [
      stub_model(Revaluation,
        :revaluation_act => nil,
        :product => nil,
        :price => "9.99"
      ),
      stub_model(Revaluation,
        :revaluation_act => nil,
        :product => nil,
        :price => "9.99"
      )
    ])
  end

  it "renders a list of revaluations" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "9.99".to_s, :count => 2
  end
end
