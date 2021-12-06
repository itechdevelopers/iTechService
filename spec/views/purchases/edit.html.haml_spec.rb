require 'rails_helper'

describe "purchases/edit" do
  before(:each) do
    @purchase = assign(:purchase, stub_model(Purchase,
      :contractor => nil,
      :store => nil
    ))
  end

  it "renders the edit purchase form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", purchase_path(@purchase), "post" do
      assert_select "input#purchase_contractor[name=?]", "purchase[contractor]"
      assert_select "input#purchase_store[name=?]", "purchase[store]"
    end
  end
end
