require "rails_helper"

describe MovementActsController do
  describe "routing" do

    it "routes to #index" do
      get("/movement_acts").should route_to("movement_acts#index")
    end

    it "routes to #new" do
      get("/movement_acts/new").should route_to("movement_acts#new")
    end

    it "routes to #show" do
      get("/movement_acts/1").should route_to("movement_acts#show", :id => "1")
    end

    it "routes to #edit" do
      get("/movement_acts/1/edit").should route_to("movement_acts#edit", :id => "1")
    end

    it "routes to #create" do
      post("/movement_acts").should route_to("movement_acts#create")
    end

    it "routes to #update" do
      put("/movement_acts/1").should route_to("movement_acts#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/movement_acts/1").should route_to("movement_acts#destroy", :id => "1")
    end

  end
end
