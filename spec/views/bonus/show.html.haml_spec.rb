require 'rails_helper'

describe "bonus/show" do
  before(:each) do
    @bonu = assign(:bonu, stub_model(Bonu,
      :bonus_type => nil,
      :comment => "MyText"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/MyText/)
  end
end
