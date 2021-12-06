require 'rails_helper'

describe "gift_certificates/show" do
  before(:each) do
    @gift_certificate = assign(:gift_certificate, stub_model(GiftCertificate,
      :number => "Number",
      :nominal => 1,
      :status => 2
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Number/)
    rendered.should match(/1/)
    rendered.should match(/2/)
  end
end
