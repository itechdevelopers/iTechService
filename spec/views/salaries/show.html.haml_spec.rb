require 'rails_helper'

describe "salaries/show" do
  before(:each) do
    @salary = assign(:salary, stub_model(Salary,
      :user => nil,
      :amount => 1
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/1/)
  end
end
