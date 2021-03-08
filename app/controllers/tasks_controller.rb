# frozen_string_literal: true

class TasksController < ApplicationController
  def index
    authorize Task
    @tasks = Task.all.order(:id).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @tasks }
    end
  end

  def show
    @task = find_record Task

    respond_to do |format|
      format.html
      format.json { @location = @task.location(params[:department_id]) }
    end
  end

  def new
    @task = authorize Task.new

    respond_to do |format|
      format.html
      format.json { render json: @task }
    end
  end

  def edit
    @task = find_record Task
  end

  def create
    @task = authorize Task.new(task_params)

    respond_to do |format|
      if @task.save
        format.html { redirect_to tasks_path, notice: t('tasks.created') }
        format.json { render json: @task, status: :created, location: @task }
      else
        format.html { render action: 'new' }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @task = find_record Task

    respond_to do |format|
      if @task.update_attributes(params[:task])
        format.html { redirect_to tasks_path, notice: t('tasks.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @task = find_record Task
    @task.destroy

    respond_to do |format|
      format.html { redirect_to tasks_url }
      format.json { head :no_content }
    end
  end

  def task_params
    params.require(:task)
          .permit(:code, :cost, :duration, :hidden, :location_code, :name, :priority, :product_id, :role)
  end
end
