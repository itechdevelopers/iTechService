require 'rails_helper'

describe "revaluations/new" do
  before(:each) do
    assign(:revaluation, stub_model(Revaluation,
      :revaluation_act => nil,
      :product => nil,
      :price => "9.99"
    ).as_new_record)
  end

  it "renders new revaluation form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", revaluations_path, "post" do
      assert_select "input#revaluation_revaluation_act[name=?]", "revaluation[revaluation_act]"
      assert_select "input#revaluation_product[name=?]", "revaluation[product]"
      assert_select "input#revaluation_price[name=?]", "revaluation[price]"
    end
  end
end
