require 'rails_helper'

describe "discounts/show" do
  before(:each) do
    @discount = assign(:discount, stub_model(Discount,
      :value => 1,
      :limit => 2
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    rendered.should match(/2/)
  end
end
