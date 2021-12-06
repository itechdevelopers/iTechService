require "rails_helper"

describe FeatureTypesController do
  describe "routing" do

    it "routes to #index" do
      get("/feature_types").should route_to("feature_types#index")
    end

    it "routes to #new" do
      get("/feature_types/new").should route_to("feature_types#new")
    end

    it "routes to #show" do
      get("/feature_types/1").should route_to("feature_types#show", :id => "1")
    end

    it "routes to #edit" do
      get("/feature_types/1/edit").should route_to("feature_types#edit", :id => "1")
    end

    it "routes to #create" do
      post("/feature_types").should route_to("feature_types#create")
    end

    it "routes to #update" do
      put("/feature_types/1").should route_to("feature_types#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/feature_types/1").should route_to("feature_types#destroy", :id => "1")
    end

  end
end
