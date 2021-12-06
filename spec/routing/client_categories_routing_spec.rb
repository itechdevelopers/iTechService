require "rails_helper"

describe ClientCategoriesController do
  describe "routing" do

    it "routes to #index" do
      get("/client_categories").should route_to("client_categories#index")
    end

    it "routes to #new" do
      get("/client_categories/new").should route_to("client_categories#new")
    end

    it "routes to #show" do
      get("/client_categories/1").should route_to("client_categories#show", :id => "1")
    end

    it "routes to #edit" do
      get("/client_categories/1/edit").should route_to("client_categories#edit", :id => "1")
    end

    it "routes to #create" do
      post("/client_categories").should route_to("client_categories#create")
    end

    it "routes to #update" do
      put("/client_categories/1").should route_to("client_categories#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/client_categories/1").should route_to("client_categories#destroy", :id => "1")
    end

  end
end
