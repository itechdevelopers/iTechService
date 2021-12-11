require "rails_helper"

describe PriceTypesController do
  describe "routing" do

    it "routes to #index" do
      get("/price_types").should route_to("price_types#index")
    end

    it "routes to #new" do
      get("/price_types/new").should route_to("price_types#new")
    end

    it "routes to #show" do
      get("/price_types/1").should route_to("price_types#show", :id => "1")
    end

    it "routes to #edit" do
      get("/price_types/1/edit").should route_to("price_types#edit", :id => "1")
    end

    it "routes to #create" do
      post("/price_types").should route_to("price_types#create")
    end

    it "routes to #update" do
      put("/price_types/1").should route_to("price_types#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/price_types/1").should route_to("price_types#destroy", :id => "1")
    end

  end
end
