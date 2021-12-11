require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

describe SupplyReportsController do

  # This should return the minimal set of attributes required to create a valid
  # SupplyReport. As you add validations to SupplyReport, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { { "date" => "2014-01-10" } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # SupplyReportsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all supply_reports as @supply_reports" do
      supply_report = SupplyReport.create! valid_attributes
      get :index, {}, valid_session
      assigns(:supply_reports).should eq([supply_report])
    end
  end

  describe "GET show" do
    it "assigns the requested supply_report as @supply_report" do
      supply_report = SupplyReport.create! valid_attributes
      get :show, {:id => supply_report.to_param}, valid_session
      assigns(:supply_report).should eq(supply_report)
    end
  end

  describe "GET new" do
    it "assigns a new supply_report as @supply_report" do
      get :new, {}, valid_session
      assigns(:supply_report).should be_a_new(SupplyReport)
    end
  end

  describe "GET edit" do
    it "assigns the requested supply_report as @supply_report" do
      supply_report = SupplyReport.create! valid_attributes
      get :edit, {:id => supply_report.to_param}, valid_session
      assigns(:supply_report).should eq(supply_report)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new SupplyReport" do
        expect {
          post :create, {:supply_report => valid_attributes}, valid_session
        }.to change(SupplyReport, :count).by(1)
      end

      it "assigns a newly created supply_report as @supply_report" do
        post :create, {:supply_report => valid_attributes}, valid_session
        assigns(:supply_report).should be_a(SupplyReport)
        assigns(:supply_report).should be_persisted
      end

      it "redirects to the created supply_report" do
        post :create, {:supply_report => valid_attributes}, valid_session
        response.should redirect_to(SupplyReport.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved supply_report as @supply_report" do
        # Trigger the behavior that occurs when invalid params are submitted
        SupplyReport.any_instance.stub(:save).and_return(false)
        post :create, {:supply_report => { "date" => "invalid value" }}, valid_session
        assigns(:supply_report).should be_a_new(SupplyReport)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        SupplyReport.any_instance.stub(:save).and_return(false)
        post :create, {:supply_report => { "date" => "invalid value" }}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested supply_report" do
        supply_report = SupplyReport.create! valid_attributes
        # Assuming there are no other supply_reports in the database, this
        # specifies that the SupplyReport created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        SupplyReport.any_instance.should_receive(:update_attributes).with({ "date" => "2014-01-10" })
        put :update, {:id => supply_report.to_param, :supply_report => { "date" => "2014-01-10" }}, valid_session
      end

      it "assigns the requested supply_report as @supply_report" do
        supply_report = SupplyReport.create! valid_attributes
        put :update, {:id => supply_report.to_param, :supply_report => valid_attributes}, valid_session
        assigns(:supply_report).should eq(supply_report)
      end

      it "redirects to the supply_report" do
        supply_report = SupplyReport.create! valid_attributes
        put :update, {:id => supply_report.to_param, :supply_report => valid_attributes}, valid_session
        response.should redirect_to(supply_report)
      end
    end

    describe "with invalid params" do
      it "assigns the supply_report as @supply_report" do
        supply_report = SupplyReport.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        SupplyReport.any_instance.stub(:save).and_return(false)
        put :update, {:id => supply_report.to_param, :supply_report => { "date" => "invalid value" }}, valid_session
        assigns(:supply_report).should eq(supply_report)
      end

      it "re-renders the 'edit' template" do
        supply_report = SupplyReport.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        SupplyReport.any_instance.stub(:save).and_return(false)
        put :update, {:id => supply_report.to_param, :supply_report => { "date" => "invalid value" }}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested supply_report" do
      supply_report = SupplyReport.create! valid_attributes
      expect {
        delete :destroy, {:id => supply_report.to_param}, valid_session
      }.to change(SupplyReport, :count).by(-1)
    end

    it "redirects to the supply_reports list" do
      supply_report = SupplyReport.create! valid_attributes
      delete :destroy, {:id => supply_report.to_param}, valid_session
      response.should redirect_to(supply_reports_url)
    end
  end

end
