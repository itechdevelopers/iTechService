require 'rails_helper'

describe "categories/index" do
  before(:each) do
    assign(:product_categories, [
      stub_model(Category,
        :name => "Name"
      ),
      stub_model(Category,
        :name => "Name"
      )
    ])
  end

  it "renders a list of categories" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
