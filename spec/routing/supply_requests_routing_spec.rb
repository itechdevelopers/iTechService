require "rails_helper"

describe SupplyRequestsController do
  describe "routing" do

    it "routes to #index" do
      get("/supply_requests").should route_to("supply_requests#index")
    end

    it "routes to #new" do
      get("/supply_requests/new").should route_to("supply_requests#new")
    end

    it "routes to #show" do
      get("/supply_requests/1").should route_to("supply_requests#show", :id => "1")
    end

    it "routes to #edit" do
      get("/supply_requests/1/edit").should route_to("supply_requests#edit", :id => "1")
    end

    it "routes to #create" do
      post("/supply_requests").should route_to("supply_requests#create")
    end

    it "routes to #update" do
      put("/supply_requests/1").should route_to("supply_requests#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/supply_requests/1").should route_to("supply_requests#destroy", :id => "1")
    end

  end
end
