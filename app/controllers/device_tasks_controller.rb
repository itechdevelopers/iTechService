# frozen_string_literal: true

class DeviceTasksController < ApplicationController
  respond_to :js

  def edit
    @device_task = find_record DeviceTask
    @modal = "device-task-#{@device_task.id}"
    render 'shared/show_modal_form'
  end

  def update
    @device_task = find_record DeviceTask

    operation = Service::DeviceTasks::Update.new.with_step_args(
      validate: [@device_task],
      save: [current_user],
      notify: [current_user, params.permit!.to_h]
    )

    operation.call(device_task_params.to_h) do |m|
      m.success { |_| render('update') }
      m.failure { |_| render('shared/show_modal_form') }
    end
  end

  def device_task_params
    params.require(:device_task)
          .permit(:comment, :cost, :done, :done_at, :performer_id, :service_job_id, :task_id, :user_comment)
          .tap do |p|
      p[:service_job_attributes] = params[:device_task][:service_job_attributes].permit! if params[:device_task][:service_job_attributes]
      p[:repair_tasks_attributes] = params[:device_task][:repair_tasks_attributes].permit! if params[:device_task][:repair_tasks_attributes]
    end
  end
end
