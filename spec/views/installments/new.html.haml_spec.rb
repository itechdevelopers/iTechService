require 'rails_helper'

describe "installments/new" do
  before(:each) do
    assign(:installment, stub_model(Installment,
      :installment_plan => nil,
      :value => 1
    ).as_new_record)
  end

  it "renders new installment form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", installments_path, "post" do
      assert_select "input#installment_installment_plan[name=?]", "installment[installment_plan]"
      assert_select "input#installment_value[name=?]", "installment[value]"
    end
  end
end
