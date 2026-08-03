# frozen_string_literal: true

require 'cgi'

# Отложенная проверка «фото при приёмке» на 60-й минуте. Ставится
# ServiceJob#schedule_reception_photo_check вместе с ReceptionPhotoReminderJob
# (30 мин) под одним guard'ом. Спустя час перепроверяем актуальное состояние
# (за это время фото могли добавить, задачу убрать, работу удалить) и, если
# фото так и нет:
#   1) автоматически выставляем создателю работы минус (Fault) с типом по
#      категории задачи — только если категория сопоставлена с FaultKind,
#      иначе минус пропускаем (см. ServiceJob#issue_reception_photo_fault!);
#   2) уведомляем сотрудника о новом минусе (in-app колокольчик + TG личка);
#   3) уведомляем супер-админов (in-app) — с пометкой, выставлен ли минус.
class ReceptionPhotoCheckJob < ApplicationJob
  # Kind надзорного уведомления супер-админам (исторический — не меняем, чтобы
  # не сбить трактовку колокольчика и дедуп по прежним записям).
  SUPERVISOR_KIND = 'reception_photo_missing'
  # Kind личного уведомления сотруднику о выставленном минусе.
  CAUSER_KIND = 'reception_photo_fault'

  queue_as :default

  def perform(service_job_id)
    service_job = ServiceJob.find_by(id: service_job_id)
    return unless service_job
    return unless service_job.reception_photo_required?
    return unless service_job.reception_photo_absent?

    fault = service_job.issue_reception_photo_fault!
    notify_causer(service_job) if fault
    notify_supervisors(service_job, fault)
  end

  private

  def notify_causer(service_job)
    recipient = service_job.user
    return if recipient.nil?
    return if Notification.exists?(referenceable: service_job, kind: CAUSER_KIND)

    message = I18n.t('notifications.reception_photo_fault', ticket: service_job.ticket_number)
    notification = Notification.create!(
      user: recipient,
      referenceable: service_job,
      message: message,
      url: url_helpers.service_job_path(service_job),
      kind: CAUSER_KIND
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)

    return unless recipient.telegram_linked?

    SendTelegramMessage.call(
      chat_id: recipient.telegram_chat_id,
      text: causer_telegram_text(service_job, message)
    )
  end

  def notify_supervisors(service_job, fault)
    return if Notification.exists?(referenceable: service_job, kind: SUPERVISOR_KIND)

    message = supervisor_message(service_job, fault)
    url = url_helpers.service_job_path(service_job)

    User.superadmins.active.find_each do |recipient|
      notification = Notification.create!(
        user: recipient,
        referenceable: service_job,
        message: message,
        url: url,
        kind: SUPERVISOR_KIND
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end

  def supervisor_message(service_job, fault)
    key = fault ? 'notifications.reception_photo_supervisor_penalized' \
                : 'notifications.reception_photo_supervisor_not_penalized'
    I18n.t(key,
           employee: service_job.user&.short_name,
           ticket: service_job.ticket_number,
           tasks: service_job.reception_photo_task_names.join(', '))
  end

  def causer_telegram_text(service_job, message)
    url = url_helpers.service_job_url(service_job, host: app_host)
    [CGI.escapeHTML(message), '', "<a href=\"#{url}\">Перейти к работе</a>"].join("\n")
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
