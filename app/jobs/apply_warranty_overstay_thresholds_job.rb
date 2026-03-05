class ApplyWarrantyOverstayThresholdsJob < ApplicationJob
  queue_as :low

  def perform
    thresholds = Setting.warranty_overstay_thresholds
    return if thresholds.blank? || !thresholds.is_a?(Array)

    ServiceJob.not_at_archive.where.not(sold_by_us_at: nil).find_each do |service_job|
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
end
