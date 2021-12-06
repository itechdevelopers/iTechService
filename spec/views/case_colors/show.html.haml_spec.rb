require 'rails_helper'

describe "case_colors/show" do
  before(:each) do
    @case_color = assign(:case_color, stub_model(CaseColor,
      :name => "Name",
      :color => "Color"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
    rendered.should match(/Color/)
  end
end
