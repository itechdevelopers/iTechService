class BackfillSoldByUsCheckJob < ApplicationJob
  queue_as :low

  def perform
    enqueued = 0

    ServiceJob.not_at_archive
              .where(one_c_device_check_status: nil)
              .includes(item: { features: :feature_type })
              .find_each do |service_job|
      next unless has_serial_number?(service_job)

      DetectSoldByUsJob.set(wait: (enqueued * 6).seconds).perform_later(service_job.id)
      enqueued += 1
    end

    Rails.logger.info "[BackfillSoldByUsCheckJob] Enqueued #{enqueued} jobs"
  end

  private

  def has_serial_number?(service_job)
    return true if service_job['serial_number'].present?

    service_job.item&.features&.any? { |f| f.feature_type&.kind == 'serial_number' && f.value.present? }
  end
end
