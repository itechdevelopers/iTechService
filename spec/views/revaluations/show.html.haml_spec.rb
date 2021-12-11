require 'rails_helper'

describe "revaluations/show" do
  before(:each) do
    @revaluation = assign(:revaluation, stub_model(Revaluation,
      :revaluation_act => nil,
      :product => nil,
      :price => "9.99"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(/9.99/)
  end
end
