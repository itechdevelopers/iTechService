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

describe CaseColorsController do

  # This should return the minimal set of attributes required to create a valid
  # CaseColor. As you add validations to CaseColor, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { { "name" => "MyString" } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # CaseColorsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all case_colors as @case_colors" do
      case_color = CaseColor.create! valid_attributes
      get :index, params: {}, session: valid_session
      assigns(:case_colors).should eq([case_color])
    end
  end

  describe "GET show" do
    it "assigns the requested case_color as @case_color" do
      case_color = CaseColor.create! valid_attributes
      get :show, params: {:id => case_color.to_param}, session: valid_session
      assigns(:case_color).should eq(case_color)
    end
  end

  describe "GET new" do
    it "assigns a new case_color as @case_color" do
      get :new, params: {}, session: valid_session
      assigns(:case_color).should be_a_new(CaseColor)
    end
  end

  describe "GET edit" do
    it "assigns the requested case_color as @case_color" do
      case_color = CaseColor.create! valid_attributes
      get :edit, params: {:id => case_color.to_param}, session: valid_session
      assigns(:case_color).should eq(case_color)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new CaseColor" do
        expect {
          post :create, params: {:case_color => valid_attributes}, session: valid_session
        }.to change(CaseColor, :count).by(1)
      end

      it "assigns a newly created case_color as @case_color" do
        post :create, params: {:case_color => valid_attributes}, session: valid_session
        assigns(:case_color).should be_a(CaseColor)
        assigns(:case_color).should be_persisted
      end

      it "redirects to the created case_color" do
        post :create, params: {:case_color => valid_attributes}, session: valid_session
        response.should redirect_to(CaseColor.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved case_color as @case_color" do
        # Trigger the behavior that occurs when invalid params are submitted
        CaseColor.any_instance.stub(:save).and_return(false)
        post :create, params: {:case_color => { "name" => "invalid value" }}, session: valid_session
        assigns(:case_color).should be_a_new(CaseColor)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        CaseColor.any_instance.stub(:save).and_return(false)
        post :create, params: {:case_color => { "name" => "invalid value" }}, session: valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested case_color" do
        case_color = CaseColor.create! valid_attributes
        # Assuming there are no other case_colors in the database, this
        # specifies that the CaseColor created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        CaseColor.any_instance.should_receive(:update_attributes).with({ "name" => "MyString" })
        put :update, params: {:id => case_color.to_param, :case_color => { "name" => "MyString" }}, session: valid_session
      end

      it "assigns the requested case_color as @case_color" do
        case_color = CaseColor.create! valid_attributes
        put :update, params: {:id => case_color.to_param, :case_color => valid_attributes}, session: valid_session
        assigns(:case_color).should eq(case_color)
      end

      it "redirects to the case_color" do
        case_color = CaseColor.create! valid_attributes
        put :update, params: {:id => case_color.to_param, :case_color => valid_attributes}, session: valid_session
        response.should redirect_to(case_color)
      end
    end

    describe "with invalid params" do
      it "assigns the case_color as @case_color" do
        case_color = CaseColor.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        CaseColor.any_instance.stub(:save).and_return(false)
        put :update, params: {:id => case_color.to_param, :case_color => { "name" => "invalid value" }}, session: valid_session
        assigns(:case_color).should eq(case_color)
      end

      it "re-renders the 'edit' template" do
        case_color = CaseColor.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        CaseColor.any_instance.stub(:save).and_return(false)
        put :update, params: {:id => case_color.to_param, :case_color => { "name" => "invalid value" }}, session: valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested case_color" do
      case_color = CaseColor.create! valid_attributes
      expect {
        delete :destroy, params: {:id => case_color.to_param}, session: valid_session
      }.to change(CaseColor, :count).by(-1)
    end

    it "redirects to the case_colors list" do
      case_color = CaseColor.create! valid_attributes
      delete :destroy, params: {:id => case_color.to_param}, session: valid_session
      response.should redirect_to(case_colors_url)
    end
  end

end
