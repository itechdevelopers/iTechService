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

describe TasksController do

  # This should return the minimal set of attributes required to create a valid
  # Task. As you add validations to Task, be sure to
  # update the return value of this method accordingly.
  def valid_attributes
    attributes_for :task
  end

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # TasksController. Be sure to keep this updated too.
  def valid_session
    {}
  end

  describe "GET index" do
    it "assigns all tasks as @tasks" do
      task = create :task
      get :index, params: {}, session: valid_session
      assigns(:tasks).should eq([task])
    end
  end

  describe "GET show" do
    it "assigns the requested task as @task" do
      task = create :task
      get :show, params: {:id => task.to_param}, session: valid_session
      assigns(:task).should eq(task)
    end
  end

  describe "GET new" do
    it "assigns a new task as @task" do
      get :new, params: {}, session: valid_session
      assigns(:task).should be_a_new(Task)
    end
  end

  describe "GET edit" do
    it "assigns the requested task as @task" do
      task = create :task
      get :edit, params: {:id => task.to_param}, session: valid_session
      assigns(:task).should eq(task)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Task" do
        expect {
          post :create, params: {:task => valid_attributes}, session: valid_session
        }.to change(Task, :count).by(1)
      end

      it "assigns a newly created task as @task" do
        post :create, params: {:task => valid_attributes}, session: valid_session
        assigns(:task).should be_a(Task)
        assigns(:task).should be_persisted
      end

      it "redirects to the created task" do
        post :create, params: {:task => valid_attributes}, session: valid_session
        response.should redirect_to(Task.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved task as @task" do
        # Trigger the behavior that occurs when invalid params are submitted
        Task.any_instance.stub(:save).and_return(false)
        post :create, params: {:task => {}}, session: valid_session
        assigns(:task).should be_a_new(Task)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Task.any_instance.stub(:save).and_return(false)
        post :create, params: {:task => {}}, session: valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested task" do
        task = create :task
        # Assuming there are no other tasks in the database, this
        # specifies that the Task created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Task.any_instance.should_receive(:update_attributes).with({'these' => 'params'})
        put :update, params: {:id => task.to_param, :task => {'these' => 'params'}}, session: valid_session
      end

      it "assigns the requested task as @task" do
        task = create :task
        put :update, params: {:id => task.to_param, :task => valid_attributes}, session: valid_session
        assigns(:task).should eq(task)
      end

      it "redirects to the task" do
        task = create :task
        put :update, params: {:id => task.to_param, :task => valid_attributes}, session: valid_session
        response.should redirect_to(task)
      end
    end

    describe "with invalid params" do
      it "assigns the task as @task" do
        task = create :task
        # Trigger the behavior that occurs when invalid params are submitted
        Task.any_instance.stub(:save).and_return(false)
        put :update, params: {:id => task.to_param, :task => {}}, session: valid_session
        assigns(:task).should eq(task)
      end

      it "re-renders the 'edit' template" do
        task = create :task
        # Trigger the behavior that occurs when invalid params are submitted
        Task.any_instance.stub(:save).and_return(false)
        put :update, params: {:id => task.to_param, :task => {}}, session: valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested task" do
      task = create :task
      expect {
        delete :destroy, params: {:id => task.to_param}, session: valid_session
      }.to change(Task, :count).by(-1)
    end

    it "redirects to the tasks list" do
      task = create :task
      delete :destroy, params: {:id => task.to_param}, session: valid_session
      response.should redirect_to(tasks_url)
    end
  end

end
