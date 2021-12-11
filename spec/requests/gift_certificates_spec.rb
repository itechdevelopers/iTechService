require 'rails_helper'

describe "GiftCertificates" do
  describe "GET /gift_certificates" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get gift_certificates_path
      response.status.should be(200)
    end
  end
end
