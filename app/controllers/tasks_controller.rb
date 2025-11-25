# frozen_string_literal: true

class TasksController < ApplicationController
  def index
    authorize Task
    @tasks = Task.all.page(params[:page])

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
      if @task.update_attributes(task_params)
        format.html { redirect_to tasks_path, notice: t('tasks.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def update_positions
    authorize Task
    positioned_tasks = JSON.parse(task_params[:tasks_positions])
    ActiveRecord::Base.transaction do
      positioned_tasks.each do |task|
        Task.find(task['id']).update(position: task['position'])
      end
    end
    respond_to do |format|
      format.js { head :ok }
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
          .permit(:code, :cost, :duration, :hidden, :location_code, :name,
                  :priority, :product_id, :role, :color, :tasks_positions,
                  service_condition_ids: [])
  end
end
