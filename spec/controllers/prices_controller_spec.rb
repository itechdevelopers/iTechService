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

describe PricesController do

  # This should return the minimal set of attributes required to create a valid
  # Price. As you add validations to Price, be sure to
  # update the return value of this method accordingly.
  def valid_attributes
    { "file" => "MyString" }
  end

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # PricesController. Be sure to keep this updated too.
  def valid_session
    {}
  end

  describe "GET index" do
    it "assigns all prices as @prices" do
      price = Price.create! valid_attributes
      get :index, params: {}, session: valid_session
      assigns(:prices).should eq([price])
    end
  end

  describe "GET show" do
    it "assigns the requested price as @price" do
      price = Price.create! valid_attributes
      get :show, params: {:id => price.to_param}, session: valid_session
      assigns(:price).should eq(price)
    end
  end

  describe "GET new" do
    it "assigns a new price as @price" do
      get :new, {}, valid_session
      assigns(:price).should be_a_new(Price)
    end
  end

  describe "GET edit" do
    it "assigns the requested price as @price" do
      price = Price.create! valid_attributes
      get :edit, {:id => price.to_param}, valid_session
      assigns(:price).should eq(price)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Price" do
        expect {
          post :create, {:price => valid_attributes}, valid_session
        }.to change(Price, :count).by(1)
      end

      it "assigns a newly created price as @price" do
        post :create, {:price => valid_attributes}, valid_session
        assigns(:price).should be_a(Price)
        assigns(:price).should be_persisted
      end

      it "redirects to the created price" do
        post :create, {:price => valid_attributes}, valid_session
        response.should redirect_to(Price.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved price as @price" do
        # Trigger the behavior that occurs when invalid params are submitted
        Price.any_instance.stub(:save).and_return(false)
        post :create, {:price => { "file" => "invalid value" }}, valid_session
        assigns(:price).should be_a_new(Price)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Price.any_instance.stub(:save).and_return(false)
        post :create, {:price => { "file" => "invalid value" }}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested price" do
        price = Price.create! valid_attributes
        # Assuming there are no other prices in the database, this
        # specifies that the Price created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Price.any_instance.should_receive(:update_attributes).with({ "file" => "MyString" })
        put :update, {:id => price.to_param, :price => { "file" => "MyString" }}, valid_session
      end

      it "assigns the requested price as @price" do
        price = Price.create! valid_attributes
        put :update, {:id => price.to_param, :price => valid_attributes}, valid_session
        assigns(:price).should eq(price)
      end

      it "redirects to the price" do
        price = Price.create! valid_attributes
        put :update, {:id => price.to_param, :price => valid_attributes}, valid_session
        response.should redirect_to(price)
      end
    end

    describe "with invalid params" do
      it "assigns the price as @price" do
        price = Price.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Price.any_instance.stub(:save).and_return(false)
        put :update, {:id => price.to_param, :price => { "file" => "invalid value" }}, valid_session
        assigns(:price).should eq(price)
      end

      it "re-renders the 'edit' template" do
        price = Price.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Price.any_instance.stub(:save).and_return(false)
        put :update, {:id => price.to_param, :price => { "file" => "invalid value" }}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested price" do
      price = Price.create! valid_attributes
      expect {
        delete :destroy, {:id => price.to_param}, valid_session
      }.to change(Price, :count).by(-1)
    end

    it "redirects to the prices list" do
      price = Price.create! valid_attributes
      delete :destroy, {:id => price.to_param}, valid_session
      response.should redirect_to(prices_url)
    end
  end

end
