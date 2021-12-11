require 'rails_helper'

describe "installments/edit" do
  before(:each) do
    @installment = assign(:installment, stub_model(Installment,
      :installment_plan => nil,
      :value => 1
    ))
  end

  it "renders the edit installment form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", installment_path(@installment), "post" do
      assert_select "input#installment_installment_plan[name=?]", "installment[installment_plan]"
      assert_select "input#installment_value[name=?]", "installment[value]"
    end
  end
end
