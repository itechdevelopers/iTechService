require 'rails_helper'

describe "case_colors/index" do
  before(:each) do
    assign(:case_colors, [
      stub_model(CaseColor,
        :name => "Name",
        :color => "Color"
      ),
      stub_model(CaseColor,
        :name => "Name",
        :color => "Color"
      )
    ])
  end

  it "renders a list of case_colors" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "Color".to_s, :count => 2
  end
end
