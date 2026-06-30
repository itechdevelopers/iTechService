# frozen_string_literal: true

# Детект «качелей статуса»: технарь обходит «Строгий ремонт», открывая суть задачи
# сменой статуса `waiting → in_progress → (прочитал) → waiting`. Маркер «айса» при
# этом не создаётся. Здесь — только in-app уведомление надзору (superadmins) в момент
# закрывающей смены. Telegram-ветку НЕ задействуем (решение заказчика).
# См. docs/repair-status-flip-detection-feature.md.
class RepairStatusFlipNotifier
  KIND = 'repair_status_flip'

  def self.call(service_job:, user:, duration:)
    new(service_job: service_job, user: user, duration: duration).call
  end

  def initialize(service_job:, user:, duration:)
    @service_job = service_job
    @user = user
    @duration = duration
  end

  def call
    User.superadmins.find_each do |recipient|
      notification = Notification.create!(
        user: recipient,
        referenceable: service_job,
        message: message,
        url: url_helpers.service_job_path(service_job),
        kind: KIND
      )
      UserNotificationChannel.broadcast_to(recipient, notification)
    end
  end

  private

  attr_reader :service_job, :user, :duration

  def message
    I18n.t('notifications.repair_status_flip',
           short_name: user.short_name,
           ticket: service_job.ticket_number,
           duration: humanized_duration)
  end

  def humanized_duration
    seconds = duration.round
    return "#{seconds} с" if seconds < 60

    minutes = seconds / 60
    rest = seconds % 60
    rest.zero? ? "#{minutes} мин" : "#{minutes} мин #{rest} с"
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
