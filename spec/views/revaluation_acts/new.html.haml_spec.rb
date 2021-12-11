require 'rails_helper'

describe "revaluation_acts/new" do
  before(:each) do
    assign(:revaluation_act, stub_model(RevaluationAct,
      :price_type => nil
    ).as_new_record)
  end

  it "renders new revaluation_act form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", revaluation_acts_path, "post" do
      assert_select "input#revaluation_act_price_type[name=?]", "revaluation_act[price_type]"
    end
  end
end
