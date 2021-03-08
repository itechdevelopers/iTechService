# frozen_string_literal: true

class QuickTasksController < ApplicationController
  def index
    authorize QuickTask
    @quick_tasks = policy_scope(QuickTask).name_asc

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @quick_tasks }
    end
  end

  def new
    @quick_task = authorize QuickTask.new

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @quick_task }
    end
  end

  def edit
    @quick_task = find_record QuickTask

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @quick_task }
    end
  end

  def create
    @quick_task = authorize QuickTask.new(quick_task_params)

    respond_to do |format|
      if @quick_task.save
        format.html { redirect_to quick_tasks_path, notice: t('quick_tasks.created') }
        format.json { render json: @quick_task, status: :created, location: @quick_task }
      else
        format.html { render 'form' }
        format.json { render json: @quick_task.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @quick_task = find_record QuickTask

    respond_to do |format|
      if @quick_task.update_attributes(quick_task_params)
        format.html { redirect_to quick_tasks_path, notice: t('quick_tasks.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @quick_task.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @quick_task = find_record QuickTask
    @quick_task.destroy

    respond_to do |format|
      format.html { redirect_to quick_tasks_url }
      format.json { head :no_content }
    end
  end

  def quick_task_params
    params.require(:quick_task)
          .permit(:name)
  end
end
