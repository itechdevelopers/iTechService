require 'cgi'

# Одноразовое напоминание: устройство пролежало на проклейке заданное
# число часов. Планируется из ServiceJobsController#update_repair_status
# через .set(wait: hours.hours).perform_later(change.id).
#
# Идемпотентность: уведомление шлётся только если переданный
# RepairStatusChange всё ещё описывает ТЕКУЩИЙ статус работы (последний
# переход). Если устройство уже сняли с проклейки (любой новый переход) —
# job завершается без побочных эффектов.
class RepairGluingReminderJob < ApplicationJob
  queue_as :default

  def perform(change_id)
    change = RepairStatusChange.find_by(id: change_id)
    return unless change

    service_job = change.service_job
    return unless current_change?(service_job, change)
    return unless service_job.repair_status&.paused? && service_job.repair_pause_reason&.gluing?

    notify_user(service_job, change)
    notify_telegram(service_job, change)
  end

  private

  def current_change?(service_job, change)
    latest = service_job.repair_status_changes.order(:changed_at).last
    latest&.id == change.id
  end

  def notify_user(service_job, change)
    recipient = change.user
    return unless recipient

    notification = Notification.create!(
      user: recipient,
      referenceable: service_job,
      message: I18n.t('notifications.repair_gluing',
                      ticket: service_job.ticket_number,
                      hours: change.gluing_hours),
      url: url_helpers.service_job_path(service_job),
      kind: 'repair_gluing'
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)
  end

  def notify_telegram(service_job, change)
    chat_id = ENV['REPAIR_GLUING_TELEGRAM_CHAT_ID']
    if chat_id.blank?
      Rails.logger.warn('[RepairGluingReminder] REPAIR_GLUING_TELEGRAM_CHAT_ID is not set; skipping Telegram')
      return
    end

    SendTelegramMessage.call(chat_id: chat_id, text: telegram_text(service_job, change))
  end

  def telegram_text(service_job, change)
    ticket = esc(service_job.ticket_number)
    device = esc(service_job.decorate.device_name)
    hours  = change.gluing_hours
    sj_url = url_helpers.service_job_url(service_job, host: app_host)

    <<~MSG.strip
      🧴 <b>На проклейке</b> — талон №#{ticket}

      Устройство «#{device}» на проклейке уже #{hours} ч — пора забирать.

      <a href="#{sj_url}">Перейти к работе</a>
    MSG
  end

  def esc(value)
    CGI.escapeHTML(value.to_s.strip)
  end

  def app_host
    ENV['SERVER_HOST'].presence ||
      Rails.application.routes.default_url_options[:host].presence ||
      'localhost:3000'
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
