class DoneTasksCopyReport < BaseReport
  attr_reader :product_group_ids, :task_ids

  params %i[product_group_ids department_id start_date end_date task_ids]

  def call
    result[:tasks] = []
    archived_service_jobs_ids = HistoryRecord.movements_to_archive(department)
                                  .in_period(period).pluck(:object_id).uniq
    scoped_archived_jobs_ids = ServiceJob.where(id: archived_service_jobs_ids)
                                  .of_product_groups(product_group_ids).pluck(:id).uniq

    result[:tasks_sum] = result[:tasks_qty] = result[:tasks_qty_free] = 0
    if archived_service_jobs_ids.any?
      tasks = DeviceTask.where service_job_id: scoped_archived_jobs_ids, task_id: task_ids
      
      tasks.collect { |t| t.task_id }.uniq.each do |task_id|
        task = Task.find task_id
        task_name = task.name
        same_tasks = tasks.where(task_id: task_id)
        task_sum = same_tasks.sum(:cost)
        task_count = same_tasks.count
        task_paid_count = same_tasks.where('cost > 0').count
        task_free_count = same_tasks.where(cost: [0, nil]).count
        service_jobs = same_tasks.collect do |same_task|
          {id: same_task.service_job.id, name: same_task.service_job.type_name, cost: same_task.cost}
        end
        result[:tasks] << {name: task_name, sum: task_sum, qty: task_count, qty_paid: task_paid_count, qty_free: task_free_count, service_jobs: service_jobs}
      end
      result[:tasks_sum] = tasks.sum(:cost)
      result[:tasks_qty] = tasks.count
      result[:tasks_qty_paid] = tasks.where('cost > 0').count
      result[:tasks_qty_free] = tasks.where(cost: [0, nil]).count
    end
    result
  end

  def product_groups_collection
    ProductGroup.devices.at_depth(1)
  end

  def tasks_collection
    Task.visible
  end

  def product_group_ids=(value)
    @product_group_ids = [value].flatten.reject(&:blank?)
  end

  def task_ids=(value)
    @task_ids = [value].flatten.reject(&:blank?)
  end
end