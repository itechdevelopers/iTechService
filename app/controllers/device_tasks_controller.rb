# frozen_string_literal: true

class DeviceTasksController < ApplicationController
  respond_to :js

  def edit
    @device_task = find_record DeviceTask
    render 'shared/show_modal_form'
  end

  def update
    @device_task = find_record DeviceTask
    operation = Service::DeviceTasks::Update.new.with_step_args(
      validate: [@device_task],
      save: [current_user],
      notify: [current_user, params]
    )

    operation.call(params[:device_task]) do |m|
      m.success { |_| render('update') }
      m.failure { |_| render('shared/show_modal_form') }
    end
  end

  def device_task_params
    params.require(:device_task)
          .permit(:comment, :cost, :done, :done_at, :performer_id, :service_job_id, :task_id, :user_comment)
    # TODO: check nested attributes for: service_job, repair_tasks
  end
end
