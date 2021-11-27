module Service
  class DeviceSubscribersNotificationJob < ApplicationJob
    queue_as :default
    attr_accessor :params

    def perform(service_job_id, user_id, params={})
      details = get_details params
      ServiceJobsMailer.staff_notice(service_job_id, user_id, details).deliver_now
    end

    private

    def get_details(params)
      res = {}

      if (note = params.fetch(:device_note, {}).fetch(:content, nil)).present?
        res[:note] = note
      end

      if (location_id = params.fetch(:service_job, {}).fetch(:location_id, nil)).present?
        location = Location.find location_id
        res[:moved_to] = location.name
      end

      if (task_params = params.fetch(:device_task, {})).present?
        task = DeviceTask.find(params[:id])
        res[:task] = {
          name: task.name,
          status: task.done_s,
          cost: task_params[:cost],
          comment: task_params[:user_comment]
        }
      end
      res
    end
  end
end