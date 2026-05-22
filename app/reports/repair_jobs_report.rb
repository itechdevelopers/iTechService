class RepairJobsReport < BaseReport
  NO_SERVICE_KEY = 'no_service'.freeze

  def call
    repair_tasks = RepairTask.includes(:device_task)
                     .in_department(department)
                     .where(device_tasks: { done_at: period, done: 1 })

    result.store :with_parts, {}
    result.store :without_parts, {}
    result.store :without_payment, {}

    repair_tasks.each do |repair_task|
      if repair_task.repair_service.present?
        repair_group_id = (repair_task.repair_group.try(:id) || '-').to_s
        repair_group_name = repair_task.repair_group.try(:name) || '-'
        repair_service_id = repair_task.repair_service_id || '-'
        repair_service_name = repair_task.name || '-'
        job = { id: repair_task.id, price: repair_task.price, parts_cost: repair_task.parts_cost, margin: repair_task.margin, device_id: repair_task.service_job.id, service_job_presentation: repair_task.service_job.presentation }
        groups = [repair_task.repair_parts.count > 0 ? :with_parts : :without_parts]
        groups << :without_payment unless repair_task.price > 0
        groups.each do |group|
          if result[group][repair_group_id].present?
            if result[group][repair_group_id][:services][repair_service_id].is_a? Hash
              result[group][repair_group_id][:jobs_qty] = result[group][repair_group_id][:jobs_qty] + 1
              result[group][repair_group_id][:services][repair_service_id][:jobs_qty] = result[group][repair_group_id][:services][repair_service_id][:jobs_qty] + 1
              result[group][repair_group_id][:services][repair_service_id][:jobs_sum] = result[group][repair_group_id][:services][repair_service_id][:jobs_sum] + repair_task.margin
              result[group][repair_group_id][:services][repair_service_id][:jobs] << job
            else
              result[group][repair_group_id][:jobs_qty] = result[group][repair_group_id][:jobs_qty] + 1
              result[group][repair_group_id][:services_qty] = result[group][repair_group_id][:services_qty] + 1
              result[group][repair_group_id][:services][repair_service_id] = { name: repair_service_name, jobs_qty: 1, jobs_sum: repair_task.margin, jobs: [job] }
            end
          else
            result[group][repair_group_id] = { name: repair_group_name, services_qty: 1, jobs_qty: 1, services: { repair_service_id => { name: repair_service_name, jobs_qty: 1, jobs_sum: repair_task.margin, jobs: [job] } } }
          end
        end
      end
    end

    add_device_tasks_without_repair_tasks
    result
  end

  private

  def add_device_tasks_without_repair_tasks
    device_tasks_without_repair_tasks.each do |device_task|
      service_job = device_task.service_job
      next if service_job.nil?

      cost = device_task.cost.to_f
      job = {
        id: "dt-#{device_task.id}",
        price: cost,
        parts_cost: 0,
        margin: cost,
        device_id: service_job.id,
        service_job_presentation: service_job.presentation
      }

      groups = [:without_parts]
      groups << :without_payment unless cost.positive?

      groups.each { |group| accumulate_orphan(group, job, cost) }
    end
  end

  def device_tasks_without_repair_tasks
    DeviceTask
      .in_department(department)
      .joins(task: :product)
      .left_joins(:repair_tasks)
      .where(done: 1, done_at: period)
      .where("products.code LIKE 'repair%'")
      .where(repair_tasks: { id: nil })
      .includes(:service_job)
  end

  def accumulate_orphan(group, job, cost)
    result[group][NO_SERVICE_KEY] ||= {
      name: I18n.t('reports.repair_jobs.without_service_group'),
      services_qty: 1,
      jobs_qty: 0,
      services: {}
    }
    result[group][NO_SERVICE_KEY][:services][NO_SERVICE_KEY] ||= {
      name: I18n.t('reports.repair_jobs.without_service'),
      jobs_qty: 0,
      jobs_sum: 0,
      jobs: []
    }

    result[group][NO_SERVICE_KEY][:jobs_qty] += 1
    result[group][NO_SERVICE_KEY][:services][NO_SERVICE_KEY][:jobs_qty] += 1
    result[group][NO_SERVICE_KEY][:services][NO_SERVICE_KEY][:jobs_sum] += cost
    result[group][NO_SERVICE_KEY][:services][NO_SERVICE_KEY][:jobs] << job
  end
end
