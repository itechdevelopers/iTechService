require 'rails_helper'

describe "prices/show" do
  before(:each) do
    @price = assign(:price, stub_model(Price,
      :file => "File"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/File/)
  end
end
