require 'rails_helper'

describe "ClientCategories" do
  describe "GET /client_categories" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get client_categories_path
      response.status.should be(200)
    end
  end
end
