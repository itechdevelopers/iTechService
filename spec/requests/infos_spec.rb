require 'rails_helper'

describe "Infos" do
  describe "GET /infos" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get infos_path
      response.status.should be(200)
    end
  end
end
