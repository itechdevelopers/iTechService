class MacServiceReport < BaseReport
  def call
    device_tasks = DeviceTask.includes(:task)
                     .where(done_at: period, task: Task.mac_service)
                     .in_department(department)

    result[:data] = {}

    device_tasks.each do |device_task|
      user_id = device_task.performer_id
      job = {id: device_task.service_job.id, presentation: device_task.service_job.presentation}
      if result[:data].key?(user_id)
        result[:data][user_id][:jobs_qty] = result[:data][user_id][:jobs_qty] + 1
        result[:data][user_id][:jobs] << job
      else
        result[:data][user_id] = {name: device_task.performer&.short_name, jobs_qty: 1, jobs: [job]}
      end
    end

    result
  end
end
