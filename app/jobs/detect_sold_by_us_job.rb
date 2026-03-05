class DetectSoldByUsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(service_job_id)
    service_job = ServiceJob.find_by(id: service_job_id)
    return unless service_job
    return if service_job.one_c_device_check_checked?
    return if service_job.serial_number.blank?

    result = DeviceStatusService.new.check_status_data(service_job.serial_number)

    if result[:success] && result[:status] == 'Продан' && result[:sold_at].present?
      service_job.update!(
        sold_by_us_at: result[:sold_at].to_date,
        one_c_device_check_status: :checked,
        one_c_device_checked_at: Time.zone.now,
        one_c_device_check_error: nil
      )
      schedule_warranty_overstay_checks(service_job)
    elsif result[:success]
      service_job.update!(
        one_c_device_check_status: :checked,
        one_c_device_checked_at: Time.zone.now,
        one_c_device_check_error: nil
      )
    else
      service_job.update!(
        one_c_device_check_status: :failed,
        one_c_device_checked_at: Time.zone.now,
        one_c_device_check_error: result[:error]
      )
      raise result[:error]
    end
  end

  private

  def schedule_warranty_overstay_checks(service_job)
    thresholds = Setting.warranty_overstay_thresholds
    thresholds = [30, 40] if thresholds.blank? || !thresholds.is_a?(Array)

    days_in_service = (Date.current - service_job.created_at.to_date).to_i

    thresholds.each do |days|
      remaining = days - days_in_service

      if remaining <= 0
        WarrantyOverstayCheckJob.perform_later(service_job.id, days)
      else
        WarrantyOverstayCheckJob.set(wait: remaining.days).perform_later(service_job.id, days)
      end
    end
  end
end
