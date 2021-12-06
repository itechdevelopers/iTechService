require "rails_helper"

describe InstallmentsController do
  describe "routing" do

    it "routes to #index" do
      get("/installments").should route_to("installments#index")
    end

    it "routes to #new" do
      get("/installments/new").should route_to("installments#new")
    end

    it "routes to #show" do
      get("/installments/1").should route_to("installments#show", :id => "1")
    end

    it "routes to #edit" do
      get("/installments/1/edit").should route_to("installments#edit", :id => "1")
    end

    it "routes to #create" do
      post("/installments").should route_to("installments#create")
    end

    it "routes to #update" do
      put("/installments/1").should route_to("installments#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/installments/1").should route_to("installments#destroy", :id => "1")
    end

  end
end
