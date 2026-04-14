class LocationOverstayCheckJob < ApplicationJob
  queue_as :default

  def perform(service_job_id, location_id, days_threshold)
    service_job = ServiceJob.find_by(id: service_job_id)
    return unless service_job
    return unless service_job.location_id == location_id

    location = service_job.location
    return unless location

    kind = "location_overstay_#{days_threshold}_loc_#{location_id}"
    return if Notification.exists?(referenceable: service_job, kind: kind)

    recipients = User.active.with_ability('receive_warranty_overstay_notifications')
    message = I18n.t(
      'notifications.location_overstay',
      ticket: service_job.ticket_number,
      location: location.name,
      days: days_threshold
    )
    url = Rails.application.routes.url_helpers.service_job_path(service_job)

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
