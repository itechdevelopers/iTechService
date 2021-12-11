require 'rails_helper'

describe "revaluation_acts/show" do
  before(:each) do
    @revaluation_act = assign(:revaluation_act, stub_model(RevaluationAct,
      :price_type => nil
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
  end
end
