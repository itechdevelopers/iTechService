require "rails_helper"

describe BonusTypesController do
  describe "routing" do

    it "routes to #index" do
      get("/bonus_types").should route_to("bonus_types#index")
    end

    it "routes to #new" do
      get("/bonus_types/new").should route_to("bonus_types#new")
    end

    it "routes to #show" do
      get("/bonus_types/1").should route_to("bonus_types#show", :id => "1")
    end

    it "routes to #edit" do
      get("/bonus_types/1/edit").should route_to("bonus_types#edit", :id => "1")
    end

    it "routes to #create" do
      post("/bonus_types").should route_to("bonus_types#create")
    end

    it "routes to #update" do
      put("/bonus_types/1").should route_to("bonus_types#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/bonus_types/1").should route_to("bonus_types#destroy", :id => "1")
    end

  end
end
