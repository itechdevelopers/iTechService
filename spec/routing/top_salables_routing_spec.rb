require "rails_helper"

describe TopSalablesController do
  describe "routing" do

    it "routes to #index" do
      get("/top_salables").should route_to("top_salables#index")
    end

    it "routes to #new" do
      get("/top_salables/new").should route_to("top_salables#new")
    end

    it "routes to #show" do
      get("/top_salables/1").should route_to("top_salables#show", :id => "1")
    end

    it "routes to #edit" do
      get("/top_salables/1/edit").should route_to("top_salables#edit", :id => "1")
    end

    it "routes to #create" do
      post("/top_salables").should route_to("top_salables#create")
    end

    it "routes to #update" do
      put("/top_salables/1").should route_to("top_salables#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/top_salables/1").should route_to("top_salables#destroy", :id => "1")
    end

  end
end
