class ServiceJobNotificationJob < ApplicationJob
  queue_as :default

  def perform(service_job_id)
    service_job = ServiceJob.find(service_job_id)

    return unless service_job.location_id.present?

    # Get all active staff (excluding API users) in the same location who want to receive notifications
    recipients = User.active.staff.located_at(service_job.location_id)
                     .joins(:user_settings)
                     .where(user_settings: { receive_location_task_notifications: true })

    message = "На вашу локацию добавлена новая работа ##{service_job.ticket_number}"
    url = Rails.application.routes.url_helpers.service_job_path(service_job)

    recipients.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        referenceable: service_job,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
