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

    operation.call(device_task_params) do |m|
      m.success { |_| render('update') }
      m.failure { |_| render('shared/show_modal_form') }
    end
  end

  def device_task_params
    params.require(:device_task).permit(
      :comment, :cost, :done, :done_at, :performer_id, :service_job_id, :task_id, :user_comment,
      service_job_attributes: [:id, :tech_notice],
      repair_tasks_attributes: [
        :id, :_destroy, :repair_service_id, :store_id, :repairer_id, :price,
        repair_parts_attributes: [
          :id, :item_id, :quantity, :warranty_term, :is_warranty, :contractor_id,
          spare_part_defects_attributes: [:id, :_destroy, :contractor_id, :qty, :is_warranty]
        ]
      ]
    )
  end
end
