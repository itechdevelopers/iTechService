require "rails_helper"

describe StolenPhonesController do
  describe "routing" do

    it "routes to #index" do
      get("/stolen_phones").should route_to("stolen_phones#index")
    end

    it "routes to #new" do
      get("/stolen_phones/new").should route_to("stolen_phones#new")
    end

    it "routes to #show" do
      get("/stolen_phones/1").should route_to("stolen_phones#show", :id => "1")
    end

    it "routes to #edit" do
      get("/stolen_phones/1/edit").should route_to("stolen_phones#edit", :id => "1")
    end

    it "routes to #create" do
      post("/stolen_phones").should route_to("stolen_phones#create")
    end

    it "routes to #update" do
      put("/stolen_phones/1").should route_to("stolen_phones#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/stolen_phones/1").should route_to("stolen_phones#destroy", :id => "1")
    end

  end
end
