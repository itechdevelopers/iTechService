require "rails_helper"

describe InstallmentPlansController do
  describe "routing" do

    it "routes to #index" do
      get("/installment_plans").should route_to("installment_plans#index")
    end

    it "routes to #new" do
      get("/installment_plans/new").should route_to("installment_plans#new")
    end

    it "routes to #show" do
      get("/installment_plans/1").should route_to("installment_plans#show", :id => "1")
    end

    it "routes to #edit" do
      get("/installment_plans/1/edit").should route_to("installment_plans#edit", :id => "1")
    end

    it "routes to #create" do
      post("/installment_plans").should route_to("installment_plans#create")
    end

    it "routes to #update" do
      put("/installment_plans/1").should route_to("installment_plans#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/installment_plans/1").should route_to("installment_plans#destroy", :id => "1")
    end

  end
end
