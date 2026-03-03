class WarrantyOverstayCheckJob < ApplicationJob
  queue_as :default

  def perform(service_job_id, days_threshold)
    service_job = ServiceJob.find_by(id: service_job_id)
    return unless service_job
    return if service_job.location&.is_archive?
    return unless service_job.sold_by_us_at.present?

    kind = "warranty_overstay_#{days_threshold}"
    return if Notification.exists?(referenceable: service_job, kind: kind)

    recipients = User.active.superadmins

    sold_date = I18n.l(service_job.sold_by_us_at)
    url = Rails.application.routes.url_helpers.service_job_path(service_job)
    message = I18n.t(
      'notifications.warranty_overstay',
      ticket: service_job.ticket_number,
      sold_date: sold_date,
      days: days_threshold
    )

    recipients.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        referenceable: service_job,
        message: message,
        url: url,
        kind: kind
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
