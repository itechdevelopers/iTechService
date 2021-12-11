require 'rails_helper'

describe "RevaluationActs" do
  describe "GET /revaluation_acts" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get revaluation_acts_path
      response.status.should be(200)
    end
  end
end
