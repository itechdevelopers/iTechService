require "rails_helper"

describe RepairGroupsController do
  describe "routing" do

    it "routes to #index" do
      get("/repair_groups").should route_to("repair_groups#index")
    end

    it "routes to #new" do
      get("/repair_groups/new").should route_to("repair_groups#new")
    end

    it "routes to #show" do
      get("/repair_groups/1").should route_to("repair_groups#show", :id => "1")
    end

    it "routes to #edit" do
      get("/repair_groups/1/edit").should route_to("repair_groups#edit", :id => "1")
    end

    it "routes to #create" do
      post("/repair_groups").should route_to("repair_groups#create")
    end

    it "routes to #update" do
      put("/repair_groups/1").should route_to("repair_groups#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/repair_groups/1").should route_to("repair_groups#destroy", :id => "1")
    end

  end
end
