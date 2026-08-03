# frozen_string_literal: true

require 'cgi'

# Одноразовое напоминание сотруднику, принявшему устройство, что через полчаса
# после создания работы у неё есть задача с require_reception_photo, а раздел
# «Фото при приёмке» всё ещё пуст. Ставится ServiceJob#schedule_reception_photo_check
# вместе с ReceptionPhotoCheckJob под одним guard'ом. Спустя 30 минут перепроверяем
# актуальное состояние (фото могли добавить, задачу убрать, работу удалить) и, если
# фото так и нет, шлём личное напоминание создателю: in-app колокольчик + TG личка.
# Образцы — ReceptionPhotoCheckJob (перепроверка условия) и RepairAttentionNotifier
# (двухканальная доставка со ссылкой на работу).
class ReceptionPhotoReminderJob < ApplicationJob
  KIND = 'reception_photo_reminder'

  queue_as :default

  def perform(service_job_id)
    service_job = ServiceJob.find_by(id: service_job_id)
    return unless service_job
    return unless service_job.reception_photo_required?
    return unless service_job.reception_photo_absent?

    recipient = service_job.user
    return if recipient.nil?
    return if Notification.exists?(referenceable: service_job, kind: KIND)

    notify_in_app(service_job, recipient)
    notify_telegram(service_job, recipient)
  end

  private

  def notify_in_app(service_job, recipient)
    notification = Notification.create!(
      user: recipient,
      referenceable: service_job,
      message: message_text(service_job.ticket_number),
      url: url_helpers.service_job_path(service_job),
      kind: KIND
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)
  end

  def notify_telegram(service_job, recipient)
    return unless recipient.telegram_linked?

    SendTelegramMessage.call(chat_id: recipient.telegram_chat_id, text: telegram_text(service_job))
  end

  def telegram_text(service_job)
    url = url_helpers.service_job_url(service_job, host: app_host)
    [
      message_text(CGI.escapeHTML(service_job.ticket_number.to_s)),
      '',
      "<a href=\"#{url}\">Перейти к работе</a>"
    ].join("\n")
  end

  def message_text(ticket)
    I18n.t('notifications.reception_photo_reminder', ticket: ticket)
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
