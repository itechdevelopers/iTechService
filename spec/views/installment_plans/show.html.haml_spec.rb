require 'rails_helper'

describe "installment_plans/show" do
  before(:each) do
    @installment_plan = assign(:installment_plan, stub_model(InstallmentPlan,
      :user => nil,
      :object => "Object",
      :cost => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Object/)
    rendered.should match(/1/)
  end
end
