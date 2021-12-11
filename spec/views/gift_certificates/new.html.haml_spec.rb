require 'rails_helper'

describe "gift_certificates/new" do
  before(:each) do
    assign(:gift_certificate, stub_model(GiftCertificate,
      :number => "MyString",
      :nominal => 1,
      :status => 1
    ).as_new_record)
  end

  it "renders new gift_certificate form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => gift_certificates_path, :method => "post" do
      assert_select "input#gift_certificate_number", :name => "gift_certificate[number]"
      assert_select "input#gift_certificate_nominal", :name => "gift_certificate[nominal]"
      assert_select "input#gift_certificate_status", :name => "gift_certificate[status]"
    end
  end
end
