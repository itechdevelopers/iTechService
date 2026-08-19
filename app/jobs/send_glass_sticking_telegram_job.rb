class SendGlassStickingTelegramJob < ApplicationJob
  queue_as :default

  def perform(glass_sticking_notification_id)
    notification = GlassStickingNotification.find(glass_sticking_notification_id)
    chat_id = ENV['TELEGRAM_GLASS_STICKING_CHAT_ID']

    unless chat_id.present?
      Rails.logger.warn("[GlassStickingTelegram] TELEGRAM_GLASS_STICKING_CHAT_ID is not set; skipping notification ##{glass_sticking_notification_id}")
      return
    end

    text = build_message(notification)
    Rails.logger.info("[GlassStickingTelegram] Queueing notification ##{glass_sticking_notification_id} for chat #{chat_id}")
    # Доставка — через SendTelegramMessageJob: у неё ретраи на сетевых сбоях.
    # Прямой вызов SendTelegramMessage терял сообщение при любом моргании связи,
    # а логирование его результата создавало ложное впечатление доставки.
    SendTelegramMessageJob.perform_later(chat_id, text)
  end

  private

  def build_message(notification)
    full_name = notification.recipient.short_name
    body = I18n.t("glass_sticking.notifications.#{notification.status}", full_name: esc(full_name))
    icon = notification.ready? ? '✅' : '⚠️'
    department = esc(notification.department.name)

    <<~MSG.strip
      #{icon} <b>Наклейка стекла</b> — #{department}

      #{body}
    MSG
  end

  def esc(text)
    CGI.escapeHTML(text.to_s)
  end
end
