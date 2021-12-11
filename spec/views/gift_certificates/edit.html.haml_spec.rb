require 'rails_helper'

describe "gift_certificates/edit" do
  before(:each) do
    @gift_certificate = assign(:gift_certificate, stub_model(GiftCertificate,
      :number => "MyString",
      :nominal => 1,
      :status => 1
    ))
  end

  it "renders the edit gift_certificate form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => gift_certificates_path(@gift_certificate), :method => "post" do
      assert_select "input#gift_certificate_number", :name => "gift_certificate[number]"
      assert_select "input#gift_certificate_nominal", :name => "gift_certificate[nominal]"
      assert_select "input#gift_certificate_status", :name => "gift_certificate[status]"
    end
  end
end
