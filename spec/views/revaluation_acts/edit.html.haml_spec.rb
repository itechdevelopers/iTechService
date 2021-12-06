require 'rails_helper'

describe "revaluation_acts/edit" do
  before(:each) do
    @revaluation_act = assign(:revaluation_act, stub_model(RevaluationAct,
      :price_type => nil
    ))
  end

  it "renders the edit revaluation_act form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", revaluation_act_path(@revaluation_act), "post" do
      assert_select "input#revaluation_act_price_type[name=?]", "revaluation_act[price_type]"
    end
  end
end
