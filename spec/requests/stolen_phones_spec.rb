require 'rails_helper'

describe "StolenPhones" do
  describe "GET /stolen_phones" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get stolen_phones_path
      response.status.should be(200)
    end
  end
end
