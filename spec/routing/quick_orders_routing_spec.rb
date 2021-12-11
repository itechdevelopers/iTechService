require "rails_helper"

describe QuickOrdersController do
  describe "routing" do

    it "routes to #index" do
      get("/quick_orders").should route_to("quick_orders#index")
    end

    it "routes to #new" do
      get("/quick_orders/new").should route_to("quick_orders#new")
    end

    it "routes to #show" do
      get("/quick_orders/1").should route_to("quick_orders#show", :id => "1")
    end

    it "routes to #edit" do
      get("/quick_orders/1/edit").should route_to("quick_orders#edit", :id => "1")
    end

    it "routes to #create" do
      post("/quick_orders").should route_to("quick_orders#create")
    end

    it "routes to #update" do
      put("/quick_orders/1").should route_to("quick_orders#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/quick_orders/1").should route_to("quick_orders#destroy", :id => "1")
    end

  end
end
