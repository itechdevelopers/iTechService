class WarrantyRepairPartsReport < BaseReport
  def call
    records = SparePartDefect
                .select(:id, :is_warranty, :qty, 'products.id AS product_id', 'products.name AS name',
                        'service_jobs.id AS job_id', 'service_jobs.ticket_number AS ticket')
                .joins(repair_part: {repair_task: {device_task: :service_job}}, item: :product)
                .warranty.where(device_tasks: {done_at: period, done: 1})

    records = records.in_department(department_ids) if department_ids.any?
    data = {}

    records.find_each do |record|
      if data.has_key?(record.product_id)
        data[record.product_id][:qty] += record.qty
        unless data[record.product_id][:jobs].has_key?(record.job_id)
          data[record.product_id][:jobs].store(record.job_id, record.ticket)
        end
      else
        data.store(record.product_id, {
          name: record.name,
          qty: 1,
          jobs: {record.job_id => record.ticket}
        })
      end
    end

    result[:data] = data
    self
  end
end