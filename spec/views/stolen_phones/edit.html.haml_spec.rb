require 'rails_helper'

describe "stolen_phones/edit" do
  before(:each) do
    @stolen_phone = assign(:stolen_phone, stub_model(StolenPhone,
      :emei => "MyString"
    ))
  end

  it "renders the edit stolen_phone form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => stolen_phones_path(@stolen_phone), :method => "post" do
      assert_select "input#stolen_phone_emei", :name => "stolen_phone[emei]"
    end
  end
end
