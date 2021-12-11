require 'rails_helper'

describe "gift_certificates/index" do
  before(:each) do
    assign(:gift_certificates, [
      stub_model(GiftCertificate,
        :number => "Number",
        :nominal => 1,
        :status => 2
      ),
      stub_model(GiftCertificate,
        :number => "Number",
        :nominal => 1,
        :status => 2
      )
    ])
  end

  it "renders a list of gift_certificates" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Number".to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => 2.to_s, :count => 2
  end
end
