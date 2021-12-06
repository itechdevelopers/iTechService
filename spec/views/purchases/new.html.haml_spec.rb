require 'rails_helper'

describe "purchases/new" do
  before(:each) do
    assign(:purchase, stub_model(Purchase,
      :contractor => nil,
      :store => nil
    ).as_new_record)
  end

  it "renders new purchase form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", purchases_path, "post" do
      assert_select "input#purchase_contractor[name=?]", "purchase[contractor]"
      assert_select "input#purchase_store[name=?]", "purchase[store]"
    end
  end
end
