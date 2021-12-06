require "rails_helper"

describe CaseColorsController do
  describe "routing" do

    it "routes to #index" do
      get("/case_colors").should route_to("case_colors#index")
    end

    it "routes to #new" do
      get("/case_colors/new").should route_to("case_colors#new")
    end

    it "routes to #show" do
      get("/case_colors/1").should route_to("case_colors#show", :id => "1")
    end

    it "routes to #edit" do
      get("/case_colors/1/edit").should route_to("case_colors#edit", :id => "1")
    end

    it "routes to #create" do
      post("/case_colors").should route_to("case_colors#create")
    end

    it "routes to #update" do
      put("/case_colors/1").should route_to("case_colors#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/case_colors/1").should route_to("case_colors#destroy", :id => "1")
    end

  end
end
