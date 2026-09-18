# frozen_string_literal: true

require 'cgi'

# Одноразовое напоминание ответственному за фото (автору задачи-триггера — при
# обычной приёмке это приёмщик), что через полчаса после появления задачи с
# require_reception_photo раздел «Фото при приёмке» всё ещё пуст. Ставится
# ServiceJob#schedule_reception_photo_check вместе с ReceptionPhotoCheckJob
# под одним guard'ом. Спустя 30 минут перепроверяем
# актуальное состояние (фото могли добавить, задачу убрать, работу удалить) и, если
# фото так и нет, шлём личное напоминание: in-app колокольчик + TG личка.
# Образцы — ReceptionPhotoCheckJob (перепроверка условия) и RepairAttentionNotifier
# (двухканальная доставка со ссылкой на работу).
class ReceptionPhotoReminderJob < ApplicationJob
  KIND = 'reception_photo_reminder'

  # Картинка едет с релизом (не через linked_dirs), поэтому путь резолвим на
  # момент отправки; если файла на месте не окажется, NotifyEmployee отправит
  # тот же текст без картинки.
  IMAGE_PATH = Rails.root.join('app', 'assets', 'images', 'telegram',
                               'reception_photo_reminder.jpg').to_s

  queue_as :default

  def perform(service_job_id)
    service_job = ServiceJob.find_by(id: service_job_id)
    return unless service_job
    return unless service_job.reception_photo_required?
    return unless service_job.reception_photo_absent?

    recipient = service_job.reception_photo_responsible
    return if recipient.nil?

    # dedup_scope прикрывает только колокольчик: он существует, чтобы в нём не
    # появилось второе напоминание. Перезапуск джобы (ретрай Sidekiq, двойное
    # планирование) всё равно доходит до Telegram — дубль напоминания меньшее
    # зло, чем молча пропавшее. Картинка едет подписью, так что push остаётся
    # один.
    NotificationDispatcher.call(
      user: recipient,
      type_key: KIND,
      kind: KIND,
      message: message_text(service_job),
      url: url_helpers.service_job_path(service_job),
      referenceable: service_job,
      telegram_text: telegram_text(service_job),
      photo_path: IMAGE_PATH,
      dedup_scope: { referenceable: service_job, kind: KIND }
    )
  end

  private

  def telegram_text(service_job)
    url = url_helpers.service_job_url(service_job, host: app_host)
    [
      CGI.escapeHTML(message_text(service_job)),
      '',
      "<a href=\"#{url}\">Перейти к работе</a>"
    ].join("\n")
  end

  # Устройство принимал один сотрудник, а задачу с обязательным фото мог дописать
  # другой — ему «ты принял устройство» сказать нельзя.
  def message_text(service_job)
    if service_job.reception_photo_added_after_reception?
      I18n.t('notifications.reception_photo_added_task_reminder',
             ticket: service_job.ticket_number,
             tasks: service_job.reception_photo_task_names.join(', '))
    else
      I18n.t('notifications.reception_photo_reminder', ticket: service_job.ticket_number)
    end
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
