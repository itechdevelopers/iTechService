require 'rails_helper'

describe "salaries/index" do
  before(:each) do
    assign(:salaries, [
      stub_model(Salary,
        :user => nil,
        :amount => 1
      ),
      stub_model(Salary,
        :user => nil,
        :amount => 1
      )
    ])
  end

  it "renders a list of salaries" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
  end
end
