require "rails_helper"

describe CashDrawersController do
  describe "routing" do

    it "routes to #index" do
      get("/cash_drawers").should route_to("cash_drawers#index")
    end

    it "routes to #new" do
      get("/cash_drawers/new").should route_to("cash_drawers#new")
    end

    it "routes to #show" do
      get("/cash_drawers/1").should route_to("cash_drawers#show", :id => "1")
    end

    it "routes to #edit" do
      get("/cash_drawers/1/edit").should route_to("cash_drawers#edit", :id => "1")
    end

    it "routes to #create" do
      post("/cash_drawers").should route_to("cash_drawers#create")
    end

    it "routes to #update" do
      put("/cash_drawers/1").should route_to("cash_drawers#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/cash_drawers/1").should route_to("cash_drawers#destroy", :id => "1")
    end

  end
end
