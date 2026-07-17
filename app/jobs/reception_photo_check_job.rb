# frozen_string_literal: true

# Одноразовая отложенная проверка «фото при приёмке».
# Ставится ServiceJob#schedule_reception_photo_check ровно через час после того,
# как у работы впервые появилась задача с флагом require_reception_photo и при
# этом раздел «Фото при приёмке» пуст. Спустя час перепроверяем актуальное
# состояние (за это время фото могли добавить, задачу — убрать, работу — удалить)
# и, если фото так и нет, шлём in-app уведомление всем супер-админам.
# Только in-app, без Telegram — как и другие «надзорные» уведомления супер-админам.
# Образец — LocationOverstayCheckJob.
class ReceptionPhotoCheckJob < ApplicationJob
  KIND = 'reception_photo_missing'

  queue_as :default

  def perform(service_job_id)
    service_job = ServiceJob.find_by(id: service_job_id)
    return unless service_job
    return unless service_job.reception_photo_required?
    return unless service_job.reception_photo_absent?
    return if Notification.exists?(referenceable: service_job, kind: KIND)

    message = I18n.t('notifications.reception_photo_missing', ticket: service_job.ticket_number)
    url = Rails.application.routes.url_helpers.service_job_path(service_job)

    User.superadmins.active.find_each do |recipient|
      notification = Notification.create!(
        user: recipient,
        referenceable: service_job,
        message: message,
        url: url,
        kind: KIND
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
