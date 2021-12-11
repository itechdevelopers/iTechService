require 'rails_helper'

describe "prices/edit" do
  before(:each) do
    @price = assign(:price, stub_model(Price,
      :file => "MyString"
    ))
  end

  it "renders the edit price form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => prices_path(@price), :method => "post" do
      assert_select "input#price_file", :name => "price[file]"
    end
  end
end
