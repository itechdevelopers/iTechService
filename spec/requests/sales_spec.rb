require 'rails_helper'

describe "SoldDevices" do
  describe "GET /sold_devices" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get sold_service_jobs_path
      response.status.should be(200)
    end
  end
end
