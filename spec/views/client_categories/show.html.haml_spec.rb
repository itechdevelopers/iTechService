require 'rails_helper'

describe "client_categories/show" do
  before(:each) do
    @client_category = assign(:client_category, stub_model(ClientCategory,
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
