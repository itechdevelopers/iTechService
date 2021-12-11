require "rails_helper"

describe TimesheetDaysController do
  describe "routing" do

    it "routes to #index" do
      get("/timesheet_days").should route_to("timesheet_days#index")
    end

    it "routes to #new" do
      get("/timesheet_days/new").should route_to("timesheet_days#new")
    end

    it "routes to #show" do
      get("/timesheet_days/1").should route_to("timesheet_days#show", :id => "1")
    end

    it "routes to #edit" do
      get("/timesheet_days/1/edit").should route_to("timesheet_days#edit", :id => "1")
    end

    it "routes to #create" do
      post("/timesheet_days").should route_to("timesheet_days#create")
    end

    it "routes to #update" do
      put("/timesheet_days/1").should route_to("timesheet_days#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/timesheet_days/1").should route_to("timesheet_days#destroy", :id => "1")
    end

  end
end
