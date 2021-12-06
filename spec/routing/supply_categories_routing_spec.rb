require "rails_helper"

describe SupplyCategoriesController do
  describe "routing" do

    it "routes to #index" do
      get("/supply_categories").should route_to("supply_categories#index")
    end

    it "routes to #new" do
      get("/supply_categories/new").should route_to("supply_categories#new")
    end

    it "routes to #show" do
      get("/supply_categories/1").should route_to("supply_categories#show", :id => "1")
    end

    it "routes to #edit" do
      get("/supply_categories/1/edit").should route_to("supply_categories#edit", :id => "1")
    end

    it "routes to #create" do
      post("/supply_categories").should route_to("supply_categories#create")
    end

    it "routes to #update" do
      put("/supply_categories/1").should route_to("supply_categories#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/supply_categories/1").should route_to("supply_categories#destroy", :id => "1")
    end

  end
end
