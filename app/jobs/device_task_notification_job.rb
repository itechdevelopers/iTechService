class DeviceTaskNotificationJob < ApplicationJob
  queue_as :default

  def perform(device_task_id)
    device_task = DeviceTask.find(device_task_id)
    service_job = device_task.service_job

    return unless service_job.present? && service_job.location_id.present?

    # Get all active staff (excluding API users) in the same location who want to receive notifications
    recipients = User.active.staff.located_at(service_job.location_id)
                     .joins(:user_settings)
                     .where(user_settings: { receive_location_task_notifications: true })

    task_name = device_task.task&.name || 'задача'
    message = "Добавлена задача \"#{task_name}\" для работы ##{service_job.ticket_number}"
    url = Rails.application.routes.url_helpers.service_job_path(service_job)

    recipients.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        referenceable: device_task,
        message: message,
        url: url
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
