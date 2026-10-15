require 'cgi'

# Срок паузы ремонта истёк. Планируется из
# ServiceJobsController#update_repair_status
# через .set(wait_until: change.pause_until).perform_later(change.id).
#
# Срабатывает, только если переданный переход всё ещё последний: любая новая
# смена статуса — продление, снятие с паузы, другая причина — делает задачу
# пустой.
#
# Паузы с автоснятием (RepairPauseReason#auto_resume?) возвращают устройство
# в «Ожидает»; тест и согласование только напоминают. Уведомление получает
# тот, кто ставил паузу. У проклейки свой тип уведомления и, кроме личного,
# сообщение в общий чат проклейки.
class RepairPauseExpiryJob < ApplicationJob
  queue_as :default

  def perform(change_id)
    change = RepairStatusChange.find_by(id: change_id)
    return unless change&.pause_until

    service_job = change.service_job
    return unless current_change?(service_job, change)

    reason = change.repair_pause_reason
    resumed = reason.auto_resume?
    service_job.change_repair_status!(waiting_status, user: nil) if resumed

    if reason.gluing?
      notify_gluing(service_job, change)
    else
      notify_pause_owner(service_job, change, resumed)
    end
  end

  private

  def current_change?(service_job, change)
    latest = service_job.repair_status_changes.order(changed_at: :desc, id: :desc).first
    latest&.id == change.id
  end

  def notify_pause_owner(service_job, change, resumed)
    key = resumed ? 'resumed' : 'reminder'
    NotificationDispatcher.call(
      user: change.user,
      type_key: 'repair_pause_expired',
      kind: 'repair_pause_expired',
      message: I18n.t("notifications.repair_pause_expired.#{key}",
                      reason: change.repair_pause_reason.name,
                      ticket: service_job.ticket_number,
                      status: waiting_status.name),
      url: url_helpers.service_job_path(service_job),
      referenceable: service_job
    )
  end

  # Общий чат получает сообщение всегда, а лично — только если сотрудник сам
  # включил себе этот канал.
  def notify_gluing(service_job, change)
    text = gluing_telegram_text(service_job, change)
    NotificationDispatcher.call(
      user: change.user,
      type_key: 'repair_gluing',
      kind: 'repair_gluing',
      message: I18n.t('notifications.repair_gluing',
                      ticket: service_job.ticket_number,
                      duration: pause_duration(change),
                      status: waiting_status.name),
      url: url_helpers.service_job_path(service_job),
      referenceable: service_job,
      telegram_text: text
    )

    chat_id = ENV['REPAIR_GLUING_TELEGRAM_CHAT_ID']
    if chat_id.blank?
      Rails.logger.warn('[RepairPauseExpiry] REPAIR_GLUING_TELEGRAM_CHAT_ID is not set; skipping Telegram')
      return
    end

    # Через SendTelegramMessageJob — она ретраит сетевые сбои; прямой вызов
    # SendTelegramMessage глотает ошибку, и напоминание пропадает без следа.
    SendTelegramMessageJob.perform_later(chat_id, text)
  end

  def gluing_telegram_text(service_job, change)
    ticket = esc(service_job.ticket_number)
    device = esc(service_job.decorate.device_name)
    sj_url = url_helpers.service_job_url(service_job, host: app_host)

    <<~MSG.strip
      🧴 <b>На проклейке</b> — талон №#{ticket}

      Устройство «#{device}» на проклейке уже #{pause_duration(change)} — пора забирать. Статус ремонта вернулся в «#{esc(waiting_status.name)}».

      <a href="#{sj_url}">Перейти к работе</a>
    MSG
  end

  def pause_duration(change)
    ApplicationController.helpers.human_repair_duration(change.pause_until - change.changed_at)
  end

  def waiting_status
    @waiting_status ||= RepairStatus.by_code(RepairStatus::WAITING)
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
