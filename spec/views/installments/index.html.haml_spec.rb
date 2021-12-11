require 'rails_helper'

describe "installments/index" do
  before(:each) do
    assign(:installments, [
      stub_model(Installment,
        :installment_plan => nil,
        :value => 1
      ),
      stub_model(Installment,
        :installment_plan => nil,
        :value => 1
      )
    ])
  end

  it "renders a list of installments" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
