require "rails_helper"

describe GiftCertificatesController do
  describe "routing" do

    it "routes to #index" do
      get("/gift_certificates").should route_to("gift_certificates#index")
    end

    it "routes to #new" do
      get("/gift_certificates/new").should route_to("gift_certificates#new")
    end

    it "routes to #show" do
      get("/gift_certificates/1").should route_to("gift_certificates#show", :id => "1")
    end

    it "routes to #edit" do
      get("/gift_certificates/1/edit").should route_to("gift_certificates#edit", :id => "1")
    end

    it "routes to #create" do
      post("/gift_certificates").should route_to("gift_certificates#create")
    end

    it "routes to #update" do
      put("/gift_certificates/1").should route_to("gift_certificates#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/gift_certificates/1").should route_to("gift_certificates#destroy", :id => "1")
    end

  end
end
