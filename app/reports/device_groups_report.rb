class DeviceGroupsReport < BaseReport
  attr_accessor :device_group_id

  def call
    result[:rows] = []
    result[:service_jobs_received_count] = result[:service_jobs_received_done_count] = result[:service_jobs_received_archived_count] = 0
    result[:current_device_group] = ProductGroup.find(device_group_id) if device_group_id.present?
    device_groups = result[:current_device_group].present? ? result[:current_device_group].children : ProductGroup.devices.at_depth(1)
    device_groups.each do |device_group|
      service_job_ids = []
      if device_group.is_childless?
        service_job_ids << service_jobs.where(products: {product_group_id: device_group.id}).pluck(:id)
      else
        device_group.descendants.each do |sub_device_group|
          if sub_device_group.is_childless?
            service_job_ids << service_jobs.where(products: {product_group_id: sub_device_group.id}).pluck(:id)
          end
        end
      end
      received_service_jobs = ServiceJob.where id: service_job_ids.flatten
      qty_received = received_service_jobs.count
      qty_done = received_service_jobs.at_done.count
      qty_archived = received_service_jobs.at_archive.count
      result[:rows] << { device_group: device_group, qty: qty_received, qty_done: qty_done, qty_archived: qty_archived }
      result[:service_jobs_received_count] += qty_received
      result[:service_jobs_received_done_count] += qty_done
      result[:service_jobs_received_archived_count] += qty_archived
    end
    result
  end

  private

  def service_jobs
    ServiceJob.includes(item: :product).received_at(period).in_department(department)
  end
end
