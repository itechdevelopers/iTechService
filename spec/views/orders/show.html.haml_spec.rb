require 'rails_helper'

describe "orders/show" do
  before(:each) do
    @order = assign(:order, stub_model(Order,
      :customer => nil,
      :object_kind => "Object Kind",
      :object => "Object",
      :comment => "MyText",
      :status => "Status"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Object Kind/)
    rendered.should match(/Object/)
    rendered.should match(/MyText/)
    rendered.should match(/Status/)
  end
end
