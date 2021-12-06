require 'rails_helper'

describe "revaluation_acts/index" do
  before(:each) do
    assign(:revaluation_acts, [
      stub_model(RevaluationAct,
        :price_type => nil
      ),
      stub_model(RevaluationAct,
        :price_type => nil
      )
    ])
  end

  it "renders a list of revaluation_acts" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
  end
end
