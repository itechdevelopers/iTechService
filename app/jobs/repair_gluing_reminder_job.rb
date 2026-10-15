require 'cgi'

# Одноразовое напоминание: срок проклейки истёк. Планируется из
# ServiceJobsController#update_repair_status
# через .set(wait_until: change.pause_until).perform_later(change.id).
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

  # Общий чат получает сообщение всегда (notify_telegram ниже), а лично —
  # только если сотрудник сам включил себе этот канал.
  def notify_user(service_job, change)
    recipient = change.user
    return unless recipient

    NotificationDispatcher.call(
      user: recipient,
      type_key: 'repair_gluing',
      kind: 'repair_gluing',
      message: I18n.t('notifications.repair_gluing',
                      ticket: service_job.ticket_number,
                      duration: gluing_duration(change)),
      url: url_helpers.service_job_path(service_job),
      referenceable: service_job,
      telegram_text: telegram_text(service_job, change)
    )
  end

  def notify_telegram(service_job, change)
    chat_id = ENV['REPAIR_GLUING_TELEGRAM_CHAT_ID']
    if chat_id.blank?
      Rails.logger.warn('[RepairGluingReminder] REPAIR_GLUING_TELEGRAM_CHAT_ID is not set; skipping Telegram')
      return
    end

    # Через SendTelegramMessageJob — она ретраит сетевые сбои; прямой вызов
    # SendTelegramMessage глотает ошибку, и напоминание пропадает без следа.
    SendTelegramMessageJob.perform_later(chat_id, telegram_text(service_job, change))
  end

  def telegram_text(service_job, change)
    ticket = esc(service_job.ticket_number)
    device = esc(service_job.decorate.device_name)
    sj_url = url_helpers.service_job_url(service_job, host: app_host)

    <<~MSG.strip
      🧴 <b>На проклейке</b> — талон №#{ticket}

      Устройство «#{device}» на проклейке уже #{gluing_duration(change)} — пора забирать.

      <a href="#{sj_url}">Перейти к работе</a>
    MSG
  end

  def gluing_duration(change)
    ApplicationController.helpers.human_repair_duration(change.pause_until - change.changed_at)
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
