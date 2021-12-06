require 'rails_helper'

describe "installments/show" do
  before(:each) do
    @installment = assign(:installment, stub_model(Installment,
      :installment_plan => nil,
      :value => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/1/)
  end
end
