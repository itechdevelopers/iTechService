require "rails_helper"

describe RepairServicesController do
  describe "routing" do

    it "routes to #index" do
      get("/repair_services").should route_to("repair_services#index")
    end

    it "routes to #new" do
      get("/repair_services/new").should route_to("repair_services#new")
    end

    it "routes to #show" do
      get("/repair_services/1").should route_to("repair_services#show", :id => "1")
    end

    it "routes to #edit" do
      get("/repair_services/1/edit").should route_to("repair_services#edit", :id => "1")
    end

    it "routes to #create" do
      post("/repair_services").should route_to("repair_services#create")
    end

    it "routes to #update" do
      put("/repair_services/1").should route_to("repair_services#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/repair_services/1").should route_to("repair_services#destroy", :id => "1")
    end

  end
end
