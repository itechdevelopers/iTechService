require "rails_helper"

describe QuickTasksController do
  describe "routing" do

    it "routes to #index" do
      get("/quick_tasks").should route_to("quick_tasks#index")
    end

    it "routes to #new" do
      get("/quick_tasks/new").should route_to("quick_tasks#new")
    end

    it "routes to #show" do
      get("/quick_tasks/1").should route_to("quick_tasks#show", :id => "1")
    end

    it "routes to #edit" do
      get("/quick_tasks/1/edit").should route_to("quick_tasks#edit", :id => "1")
    end

    it "routes to #create" do
      post("/quick_tasks").should route_to("quick_tasks#create")
    end

    it "routes to #update" do
      put("/quick_tasks/1").should route_to("quick_tasks#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/quick_tasks/1").should route_to("quick_tasks#destroy", :id => "1")
    end

  end
end
