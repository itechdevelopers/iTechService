require 'rails_helper'

describe "installment_plans/edit" do
  before(:each) do
    @installment_plan = assign(:installment_plan, stub_model(InstallmentPlan,
      :user => nil,
      :object => "MyString",
      :cost => 1
    ))
  end

  it "renders the edit installment_plan form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", installment_plan_path(@installment_plan), "post" do
      assert_select "input#installment_plan_user[name=?]", "installment_plan[user]"
      assert_select "input#installment_plan_object[name=?]", "installment_plan[object]"
      assert_select "input#installment_plan_cost[name=?]", "installment_plan[cost]"
    end
  end
end
