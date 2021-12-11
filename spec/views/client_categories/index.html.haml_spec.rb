require 'rails_helper'

describe "client_categories/index" do
  before(:each) do
    assign(:client_categories, [
      stub_model(ClientCategory,
        :name => "Name",
        :color => "Color"
      ),
      stub_model(ClientCategory,
        :name => "Name",
        :color => "Color"
      )
    ])
  end

  it "renders a list of client_categories" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "Color".to_s, :count => 2
  end
end
