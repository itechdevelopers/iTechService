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
      NotificationDispatcher.call(
        user: recipient,
        type_key: 'service_job_location_added',
        message: message,
        url: url,
        referenceable: service_job
      )
    end
  end
end
