require 'rails_helper'

describe "Revaluations" do
  describe "GET /revaluations" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get revaluations_path
      response.status.should be(200)
    end
  end
end
