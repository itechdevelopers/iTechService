# frozen_string_literal: true

class RepeatedRepairReport < BaseReport
  def call
    jobs = ServiceJob.select('item_id, device_type_id, serial_number, imei, count(*) qty')
                     .group('item_id, device_type_id, serial_number, imei').having('count(*) > 1')
    jobs = jobs.in_department(department) if department
    jobs = jobs.where(created_at: period)
    result[:jobs] = jobs
    result
  end
end
