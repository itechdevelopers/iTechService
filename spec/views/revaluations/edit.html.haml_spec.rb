require 'rails_helper'

describe "revaluations/edit" do
  before(:each) do
    @revaluation = assign(:revaluation, stub_model(Revaluation,
      :revaluation_act => nil,
      :product => nil,
      :price => "9.99"
    ))
  end

  it "renders the edit revaluation form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", revaluation_path(@revaluation), "post" do
      assert_select "input#revaluation_revaluation_act[name=?]", "revaluation[revaluation_act]"
      assert_select "input#revaluation_product[name=?]", "revaluation[product]"
      assert_select "input#revaluation_price[name=?]", "revaluation[price]"
    end
  end
end
