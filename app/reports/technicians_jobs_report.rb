class TechniciansJobsReport < BaseReport
  def call
    repair_tasks = RepairTask.includes(:device_task)
                     .in_department(department)
                     .where(device_tasks: {done_at: period})

    total_sum = 0
    result[:data] = {}

    repair_tasks.each do |repair_task|
      user_id = repair_task.performer.try(:id).to_s
      user_name = repair_task.performer.try(:short_name)
      job = { id: repair_task.id, name: repair_task.name, price: repair_task.price, parts_cost: repair_task.parts_cost, margin: repair_task.margin, device_id: repair_task.service_job.id, service_job_presentation: repair_task.service_job.presentation }
      if result[:data][user_id].present?
        result[:data][user_id][:jobs_qty] = result[:data][user_id][:jobs_qty] + 1
        result[:data][user_id][:jobs_sum] = result[:data][user_id][:jobs_sum] + repair_task.margin
        result[:data][user_id][:jobs] << job
      else
        result[:data][user_id] = { name: user_name, jobs_qty: 1, jobs_sum: repair_task.margin, jobs: [job] }
      end
      total_sum += repair_task.margin
    end

    total_sum = add_device_tasks_without_repair_tasks(total_sum)

    result[:total_sum] = total_sum
    result
  end

  private

  def add_device_tasks_without_repair_tasks(total_sum)
    device_tasks_without_repair_tasks.each do |device_task|
      service_job = device_task.service_job
      next if service_job.nil?

      user_id = device_task.performer.try(:id).to_s
      user_name = device_task.performer.try(:short_name)
      cost = device_task.cost.to_f
      job = {
        id: "dt-#{device_task.id}",
        name: I18n.t('reports.technicians_jobs.without_service'),
        price: cost,
        parts_cost: 0,
        margin: cost,
        device_id: service_job.id,
        service_job_presentation: service_job.presentation
      }
      if result[:data][user_id].present?
        result[:data][user_id][:jobs_qty] += 1
        result[:data][user_id][:jobs_sum] += cost
        result[:data][user_id][:jobs] << job
      else
        result[:data][user_id] = { name: user_name, jobs_qty: 1, jobs_sum: cost, jobs: [job] }
      end
      total_sum += cost
    end
    total_sum
  end

  def device_tasks_without_repair_tasks
    DeviceTask
      .in_department(department)
      .joins(task: :product)
      .left_joins(:repair_tasks)
      .where(done_at: period)
      .where("products.code LIKE 'repair%'")
      .where(repair_tasks: { id: nil })
      .includes(:service_job, :performer)
  end
end
