require 'cgi'

class RepairAttentionNotifier
  def self.call(marker)
    new(marker).call
  end

  def initialize(marker)
    @marker = marker
  end

  def call
    notify_user
    notify_telegram
  end

  private

  attr_reader :marker

  def notify_user
    notification = Notification.create!(
      user: marker.user,
      referenceable: marker.service_job,
      message: I18n.t('notifications.repair_attention',
                      ticket: marker.service_job.ticket_number),
      url: url_helpers.service_job_path(marker.service_job),
      kind: 'repair_attention'
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)
  end

  def notify_telegram
    chat_id = ENV['REPAIR_ATTENTION_TELEGRAM_CHAT_ID']
    return if chat_id.blank?

    SendTelegramMessage.call(chat_id: chat_id, text: telegram_text)
  end

  def telegram_text
    user = marker.user
    sj   = marker.service_job
    mention = user.telegram_username.present? ? "@#{esc(user.telegram_username)} " : ''
    full_name = esc(user.full_name)
    ticket = esc(sj.ticket_number)
    client = esc(sj.client&.presentation)
    device = esc(sj.decorate.device_name)

    sj_url      = url_helpers.service_job_url(sj, host: app_host)
    start_url   = url_helpers.start_repair_repair_attention_marker_url(
                    marker, token: marker.start_token, host: app_host)
    dismiss_url = url_helpers.dismiss_repair_attention_marker_url(
                    marker, token: marker.dismiss_token, host: app_host)

    <<~HTML.strip
      #{mention}#{full_name}, ты смотрел эту задачу <a href="#{sj_url}">#{ticket}</a>
      #{client} #{device}.
      Ты приступил к ремонту или просто посмотрел?

      <a href="#{start_url}">Приступил к ремонту</a> | <a href="#{dismiss_url}">Просто посмотрел</a>
    HTML
  end

  def esc(value)
    CGI.escapeHTML(value.to_s.strip)
  end

  def app_host
    ENV.fetch('APP_HOST', 'localhost:3000')
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
