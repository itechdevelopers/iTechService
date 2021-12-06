require "rails_helper"

describe SalesController do
  describe "routing" do

    it "routes to #index" do
      get("/sold_devices").should route_to("sold_devices#index")
    end

    it "routes to #new" do
      get("/sold_devices/new").should route_to("sold_devices#new")
    end

    it "routes to #show" do
      get("/sold_devices/1").should route_to("sold_devices#show", :id => "1")
    end

    it "routes to #edit" do
      get("/sold_devices/1/edit").should route_to("sold_devices#edit", :id => "1")
    end

    it "routes to #create" do
      post("/sold_devices").should route_to("sold_devices#create")
    end

    it "routes to #update" do
      put("/sold_devices/1").should route_to("sold_devices#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/sold_devices/1").should route_to("sold_devices#destroy", :id => "1")
    end

  end
end
