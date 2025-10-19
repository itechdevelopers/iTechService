# frozen_string_literal: true

class DeviceTasksController < ApplicationController
  respond_to :js

  def edit
    @device_task = find_record DeviceTask
    @modal = "device-task-#{@device_task.id}"
    build_device_note
    render 'shared/show_modal_form'
  end

  def update
    @device_task = find_record DeviceTask
    build_device_note

    # Filter service job attributes based on permissions
    filtered_params = device_task_params.to_h
    if filtered_params[:service_job_attributes].present?
      unless policy(@device_task.service_job).update? || policy(@device_task.service_job).move_transfers?
        filtered_params.delete(:service_job_attributes)
      end
    end

    operation = Service::DeviceTasks::Update.new.with_step_args(
      validate: [@device_task],
      save: [current_user],
      notify: [current_user, params.permit!.to_h]
    )

    operation.call(filtered_params) do |m|
      m.success { |_| render('update') }
      m.failure { |_| render('shared/show_modal_form') }
    end
  end

  def build_device_note
    @service_job = @device_task.service_job
    @device_note = DeviceNote.new user_id: current_user.id, service_job_id: @service_job.id
  end

  def device_task_params
    params.require(:device_task)
          .permit(:comment, :cost, :done, :done_at, :performer_id, :service_job_id, :task_id, :user_comment, check_list_responses_attributes: [:id, :check_list_id, responses: {}])
          .tap do |p|
      if params[:device_task][:service_job_attributes]
        # Explicitly whitelist service job attributes for security
        # MUST include :id for updating existing records via nested attributes
        p[:service_job_attributes] = params[:device_task][:service_job_attributes]
                                      .permit(:id, :tech_notice, :location_id, :client_notified)
      end
      p[:repair_tasks_attributes] = params[:device_task][:repair_tasks_attributes].permit! if params[:device_task][:repair_tasks_attributes]
    end
  end
end
