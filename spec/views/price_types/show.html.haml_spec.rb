require 'rails_helper'

describe "price_types/show" do
  before(:each) do
    @price_type = assign(:price_type, stub_model(PriceType,
      :name => "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
  end
end
