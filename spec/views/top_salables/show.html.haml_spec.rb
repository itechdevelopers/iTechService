require 'rails_helper'

describe "top_salables/show" do
  before(:each) do
    @top_salable = assign(:top_salable, stub_model(TopSalable,
      :salable => nil,
      :position => 1,
      :color => "Color"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/1/)
    rendered.should match(/Color/)
  end
end
