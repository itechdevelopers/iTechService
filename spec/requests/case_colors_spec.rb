require 'rails_helper'

describe "CaseColors" do
  describe "GET /case_colors" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get case_colors_path
      response.status.should be(200)
    end
  end
end
