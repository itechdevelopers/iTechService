require 'rails_helper'

describe "Banks" do
  describe "GET /banks" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get banks_path
      response.status.should be(200)
    end
  end
end
