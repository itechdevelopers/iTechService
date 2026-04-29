class CheckQueueInactivityJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 120
  RECHECK_INTERVAL = 1.minute
  KIND = 'queue_inactivity_alert'.freeze

  def perform(waiting_client_id, attempt = 1)
    return if attempt > MAX_ATTEMPTS

    waiting_client = WaitingClient.find_by(id: waiting_client_id)
    return unless waiting_client&.status == 'waiting'

    detector = QueueInactivityDetector.new(waiting_client)
    notify!(waiting_client, detector) if detector.threshold_exceeded?

    self.class.set(wait: RECHECK_INTERVAL).perform_later(waiting_client_id, attempt + 1)
  end

  private

  def notify!(waiting_client, detector)
    return if Notification.exists?(referenceable: waiting_client, kind: KIND)

    if waiting_client.unattended_started_at.nil?
      waiting_client.update_columns(unattended_started_at: Time.zone.now)
    end

    message = I18n.t('notifications.queue_inactivity',
                     ticket: waiting_client.ticket_number,
                     queue: waiting_client.electronic_queue.queue_name,
                     waited: (detector.waited_seconds / 60.0).round(1),
                     total: detector.total_on_shift,
                     active: detector.active_users_count)

    User.superadmins.find_each do |admin|
      notification = Notification.create!(
        user: admin,
        referenceable: waiting_client,
        message: message,
        url: Rails.application.routes.url_helpers.root_path,
        kind: KIND
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
