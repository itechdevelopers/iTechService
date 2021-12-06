require "rails_helper"

describe RevaluationActsController do
  describe "routing" do

    it "routes to #index" do
      get("/revaluation_acts").should route_to("revaluation_acts#index")
    end

    it "routes to #new" do
      get("/revaluation_acts/new").should route_to("revaluation_acts#new")
    end

    it "routes to #show" do
      get("/revaluation_acts/1").should route_to("revaluation_acts#show", :id => "1")
    end

    it "routes to #edit" do
      get("/revaluation_acts/1/edit").should route_to("revaluation_acts#edit", :id => "1")
    end

    it "routes to #create" do
      post("/revaluation_acts").should route_to("revaluation_acts#create")
    end

    it "routes to #update" do
      put("/revaluation_acts/1").should route_to("revaluation_acts#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/revaluation_acts/1").should route_to("revaluation_acts#destroy", :id => "1")
    end

  end
end
