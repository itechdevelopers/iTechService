require "rails_helper"

describe CashOperationsController do
  describe "routing" do

    it "routes to #index" do
      get("/cash_operations").should route_to("cash_operations#index")
    end

    it "routes to #new" do
      get("/cash_operations/new").should route_to("cash_operations#new")
    end

    it "routes to #show" do
      get("/cash_operations/1").should route_to("cash_operations#show", :id => "1")
    end

    it "routes to #edit" do
      get("/cash_operations/1/edit").should route_to("cash_operations#edit", :id => "1")
    end

    it "routes to #create" do
      post("/cash_operations").should route_to("cash_operations#create")
    end

    it "routes to #update" do
      put("/cash_operations/1").should route_to("cash_operations#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/cash_operations/1").should route_to("cash_operations#destroy", :id => "1")
    end

  end
end
