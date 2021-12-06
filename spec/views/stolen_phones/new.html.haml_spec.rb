require 'rails_helper'

describe "stolen_phones/new" do
  before(:each) do
    assign(:stolen_phone, stub_model(StolenPhone,
      :emei => "MyString"
    ).as_new_record)
  end

  it "renders new stolen_phone form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => stolen_phones_path, :method => "post" do
      assert_select "input#stolen_phone_emei", :name => "stolen_phone[emei]"
    end
  end
end
