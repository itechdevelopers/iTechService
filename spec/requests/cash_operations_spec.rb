require 'rails_helper'

describe "CashOperations" do
  describe "GET /cash_operations" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get cash_operations_path
      response.status.should be(200)
    end
  end
end
