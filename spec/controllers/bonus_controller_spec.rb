require 'spec_helper'

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

describe BonusController do

  # This should return the minimal set of attributes required to create a valid
  # Bonu. As you add validations to Bonu, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { { "bonus_type" => "" } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # BonusController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all bonus as @bonus" do
      bonu = Bonu.create! valid_attributes
      get :index, {}, valid_session
      assigns(:bonus).should eq([bonu])
    end
  end

  describe "GET show" do
    it "assigns the requested bonu as @bonu" do
      bonu = Bonu.create! valid_attributes
      get :show, {:id => bonu.to_param}, valid_session
      assigns(:bonu).should eq(bonu)
    end
  end

  describe "GET new" do
    it "assigns a new bonu as @bonu" do
      get :new, {}, valid_session
      assigns(:bonu).should be_a_new(Bonu)
    end
  end

  describe "GET edit" do
    it "assigns the requested bonu as @bonu" do
      bonu = Bonu.create! valid_attributes
      get :edit, {:id => bonu.to_param}, valid_session
      assigns(:bonu).should eq(bonu)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Bonu" do
        expect {
          post :create, {:bonu => valid_attributes}, valid_session
        }.to change(Bonu, :count).by(1)
      end

      it "assigns a newly created bonu as @bonu" do
        post :create, {:bonu => valid_attributes}, valid_session
        assigns(:bonu).should be_a(Bonu)
        assigns(:bonu).should be_persisted
      end

      it "redirects to the created bonu" do
        post :create, {:bonu => valid_attributes}, valid_session
        response.should redirect_to(Bonu.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved bonu as @bonu" do
        # Trigger the behavior that occurs when invalid params are submitted
        Bonu.any_instance.stub(:save).and_return(false)
        post :create, {:bonu => { "bonus_type" => "invalid value" }}, valid_session
        assigns(:bonu).should be_a_new(Bonu)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Bonu.any_instance.stub(:save).and_return(false)
        post :create, {:bonu => { "bonus_type" => "invalid value" }}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested bonu" do
        bonu = Bonu.create! valid_attributes
        # Assuming there are no other bonus in the database, this
        # specifies that the Bonu created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Bonu.any_instance.should_receive(:update_attributes).with({ "bonus_type" => "" })
        put :update, {:id => bonu.to_param, :bonu => { "bonus_type" => "" }}, valid_session
      end

      it "assigns the requested bonu as @bonu" do
        bonu = Bonu.create! valid_attributes
        put :update, {:id => bonu.to_param, :bonu => valid_attributes}, valid_session
        assigns(:bonu).should eq(bonu)
      end

      it "redirects to the bonu" do
        bonu = Bonu.create! valid_attributes
        put :update, {:id => bonu.to_param, :bonu => valid_attributes}, valid_session
        response.should redirect_to(bonu)
      end
    end

    describe "with invalid params" do
      it "assigns the bonu as @bonu" do
        bonu = Bonu.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Bonu.any_instance.stub(:save).and_return(false)
        put :update, {:id => bonu.to_param, :bonu => { "bonus_type" => "invalid value" }}, valid_session
        assigns(:bonu).should eq(bonu)
      end

      it "re-renders the 'edit' template" do
        bonu = Bonu.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Bonu.any_instance.stub(:save).and_return(false)
        put :update, {:id => bonu.to_param, :bonu => { "bonus_type" => "invalid value" }}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested bonu" do
      bonu = Bonu.create! valid_attributes
      expect {
        delete :destroy, {:id => bonu.to_param}, valid_session
      }.to change(Bonu, :count).by(-1)
    end

    it "redirects to the bonus list" do
      bonu = Bonu.create! valid_attributes
      delete :destroy, {:id => bonu.to_param}, valid_session
      response.should redirect_to(bonus_url)
    end
  end

end
