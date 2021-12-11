require 'rails_helper'

describe "salaries/new" do
  before(:each) do
    assign(:salary, stub_model(Salary,
      :user => nil,
      :amount => 1
    ).as_new_record)
  end

  it "renders new salary form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => salaries_path, :method => "post" do
      assert_select "input#salary_user", :name => "salary[user]"
      assert_select "input#salary_amount", :name => "salary[amount]"
    end
  end
end
