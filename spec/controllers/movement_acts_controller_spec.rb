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

describe MovementActsController do

  # This should return the minimal set of attributes required to create a valid
  # MovementAct. As you add validations to MovementAct, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { { "date" => "2013-11-18 18:28:10" } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # MovementActsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all movement_acts as @movement_acts" do
      movement_act = MovementAct.create! valid_attributes
      get :index, {}, valid_session
      assigns(:movement_acts).should eq([movement_act])
    end
  end

  describe "GET show" do
    it "assigns the requested movement_act as @movement_act" do
      movement_act = MovementAct.create! valid_attributes
      get :show, {:id => movement_act.to_param}, valid_session
      assigns(:movement_act).should eq(movement_act)
    end
  end

  describe "GET new" do
    it "assigns a new movement_act as @movement_act" do
      get :new, {}, valid_session
      assigns(:movement_act).should be_a_new(MovementAct)
    end
  end

  describe "GET edit" do
    it "assigns the requested movement_act as @movement_act" do
      movement_act = MovementAct.create! valid_attributes
      get :edit, {:id => movement_act.to_param}, valid_session
      assigns(:movement_act).should eq(movement_act)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new MovementAct" do
        expect {
          post :create, {:movement_act => valid_attributes}, valid_session
        }.to change(MovementAct, :count).by(1)
      end

      it "assigns a newly created movement_act as @movement_act" do
        post :create, {:movement_act => valid_attributes}, valid_session
        assigns(:movement_act).should be_a(MovementAct)
        assigns(:movement_act).should be_persisted
      end

      it "redirects to the created movement_act" do
        post :create, {:movement_act => valid_attributes}, valid_session
        response.should redirect_to(MovementAct.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved movement_act as @movement_act" do
        # Trigger the behavior that occurs when invalid params are submitted
        MovementAct.any_instance.stub(:save).and_return(false)
        post :create, {:movement_act => { "date" => "invalid value" }}, valid_session
        assigns(:movement_act).should be_a_new(MovementAct)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        MovementAct.any_instance.stub(:save).and_return(false)
        post :create, {:movement_act => { "date" => "invalid value" }}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested movement_act" do
        movement_act = MovementAct.create! valid_attributes
        # Assuming there are no other movement_acts in the database, this
        # specifies that the MovementAct created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        MovementAct.any_instance.should_receive(:update_attributes).with({ "date" => "2013-11-18 18:28:10" })
        put :update, {:id => movement_act.to_param, :movement_act => { "date" => "2013-11-18 18:28:10" }}, valid_session
      end

      it "assigns the requested movement_act as @movement_act" do
        movement_act = MovementAct.create! valid_attributes
        put :update, {:id => movement_act.to_param, :movement_act => valid_attributes}, valid_session
        assigns(:movement_act).should eq(movement_act)
      end

      it "redirects to the movement_act" do
        movement_act = MovementAct.create! valid_attributes
        put :update, {:id => movement_act.to_param, :movement_act => valid_attributes}, valid_session
        response.should redirect_to(movement_act)
      end
    end

    describe "with invalid params" do
      it "assigns the movement_act as @movement_act" do
        movement_act = MovementAct.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        MovementAct.any_instance.stub(:save).and_return(false)
        put :update, {:id => movement_act.to_param, :movement_act => { "date" => "invalid value" }}, valid_session
        assigns(:movement_act).should eq(movement_act)
      end

      it "re-renders the 'edit' template" do
        movement_act = MovementAct.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        MovementAct.any_instance.stub(:save).and_return(false)
        put :update, {:id => movement_act.to_param, :movement_act => { "date" => "invalid value" }}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested movement_act" do
      movement_act = MovementAct.create! valid_attributes
      expect {
        delete :destroy, {:id => movement_act.to_param}, valid_session
      }.to change(MovementAct, :count).by(-1)
    end

    it "redirects to the movement_acts list" do
      movement_act = MovementAct.create! valid_attributes
      delete :destroy, {:id => movement_act.to_param}, valid_session
      response.should redirect_to(movement_acts_url)
    end
  end

end
