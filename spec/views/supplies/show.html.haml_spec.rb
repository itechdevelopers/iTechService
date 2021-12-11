require 'rails_helper'

describe "supplies/show" do
  before(:each) do
    @supply = assign(:supply, stub_model(Supply,
      :supply_report => nil,
      :supply_category => nil,
      :name => "",
      :quantity => 1,
      :cost => "9.99"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(/1/)
    rendered.should match(/9.99/)
  end
end
