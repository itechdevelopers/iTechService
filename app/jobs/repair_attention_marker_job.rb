class RepairAttentionMarkerJob < ApplicationJob
  queue_as :default

  def perform(marker_id)
    marker = RepairAttentionMarker.find_by(id: marker_id)
    return unless marker
    return if marker.processed?

    if status_changed?(marker)
      marker.mark_auto_resolved!
      return
    end

    notify_user(marker)
    marker.update!(notified_at: Time.zone.now)
  end

  private

  def status_changed?(marker)
    marker.service_job.repair_status_id != marker.status_at_view_id
  end

  def notify_user(marker)
    notification = Notification.create!(
      user: marker.user,
      referenceable: marker.service_job,
      message: I18n.t('notifications.repair_attention',
                      ticket: marker.service_job.ticket_number),
      url: Rails.application.routes.url_helpers.service_job_path(marker.service_job),
      kind: 'repair_attention'
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)
  end
end
