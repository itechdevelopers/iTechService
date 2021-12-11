require 'rails_helper'

describe "purchases/show" do
  before(:each) do
    @purchase = assign(:purchase, stub_model(Purchase,
      :contractor => nil,
      :store => nil
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(//)
  end
end
