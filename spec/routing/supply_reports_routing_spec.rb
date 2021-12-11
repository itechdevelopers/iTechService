require "rails_helper"

describe SupplyReportsController do
  describe "routing" do

    it "routes to #index" do
      get("/supply_reports").should route_to("supply_reports#index")
    end

    it "routes to #new" do
      get("/supply_reports/new").should route_to("supply_reports#new")
    end

    it "routes to #show" do
      get("/supply_reports/1").should route_to("supply_reports#show", :id => "1")
    end

    it "routes to #edit" do
      get("/supply_reports/1/edit").should route_to("supply_reports#edit", :id => "1")
    end

    it "routes to #create" do
      post("/supply_reports").should route_to("supply_reports#create")
    end

    it "routes to #update" do
      put("/supply_reports/1").should route_to("supply_reports#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/supply_reports/1").should route_to("supply_reports#destroy", :id => "1")
    end

  end
end
