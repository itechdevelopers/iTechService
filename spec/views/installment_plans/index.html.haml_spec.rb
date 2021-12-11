require 'rails_helper'

describe "installment_plans/index" do
  before(:each) do
    assign(:installment_plans, [
      stub_model(InstallmentPlan,
        :user => nil,
        :object => "Object",
        :cost => 1
      ),
      stub_model(InstallmentPlan,
        :user => nil,
        :object => "Object",
        :cost => 1
      )
    ])
  end

  it "renders a list of installment_plans" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Object".to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
