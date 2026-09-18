# frozen_string_literal: true

require 'cgi'

# Единственная точка доставки уведомления сотруднику. Отправитель сообщает, что
# случилось и кому это адресовано; куда доставлять — решается здесь, по
# персональной настройке получателя.
#
#   NotificationDispatcher.call(
#     user: recipient, type_key: 'repair_gluing',
#     message: 'Устройство на проклейке уже 6 ч',
#     url: service_job_path(job), referenceable: job
#   )
#
# Запись в notifications создаётся всегда, даже когда сотрудник отключил себе
# колокольчик: на Notification.exists? держится защита от дублей в джобах, в
# профиле остаётся журнал, а повторам нужна точка остановки (closed_at). При
# отключённом колокольчике запись помечается hidden_at и в поповер не попадает.
#
# Текст для Telegram по умолчанию собирается из message и ссылки. Отправитель
# передаёт telegram_text сам, только если ему нужна своя разметка — кнопки
# маячка, дайджест, подпись под фотографией.
class NotificationDispatcher
  LINK_LABEL = 'Открыть в АйСе'

  def self.call(**args)
    new(**args).call
  end

  def initialize(user:, type_key:, message:, url: nil, referenceable: nil,
                 kind: nil, telegram_text: nil, photo_path: nil, dedup_scope: nil)
    @user = user
    @type_key = type_key
    @message = message
    @url = url
    @referenceable = referenceable
    @kind = kind
    @telegram_text = telegram_text
    @photo_path = photo_path
    @dedup_scope = dedup_scope
  end

  def call
    return if user.nil? || message.blank?

    notification = existing_notification || create_notification
    deliver_telegram
    notification
  end

  private

  attr_reader :user, :type_key, :message, :url, :referenceable, :kind,
              :telegram_text, :photo_path, :dedup_scope

  # Повод, о котором уже уведомляли: второй записи в колокольчике не нужно, но
  # доставку в Telegram это не отменяет — отправитель мог не дойти с первого
  # раза, и повторное напоминание меньшее зло, чем молча пропавшее. Видимую
  # запись переброадкастим: иконка снова привлечёт внимание.
  def existing_notification
    return nil if dedup_scope.blank?

    found = Notification.find_by(dedup_scope)
    return nil if found.nil?

    UserNotificationChannel.broadcast_to(user, found) unless found.hidden?
    found
  end

  def create_notification
    notification = Notification.create!(
      user: user,
      message: message,
      url: url,
      referenceable: referenceable,
      kind: kind,
      type_key: type_key,
      hidden_at: in_app? ? nil : Time.zone.now
    )
    UserNotificationChannel.broadcast_to(user, notification) if in_app?
    notification
  end

  def deliver_telegram
    return unless telegram?
    return unless user.telegram_linked?

    NotifyEmployeeJob.perform_later(user.id, telegram_body, photo_path)
  end

  # Тип, которого нет в каталоге, доставляется по-старому: колокольчик да,
  # личный Telegram нет — раньше его слал сам отправитель. Так неизвестный ключ
  # не превращается в потерянное уведомление.
  def preference
    return @preference if defined?(@preference)

    @preference = UserNotificationPreference.for(user, type_key)
  end

  def in_app?
    preference.nil? || preference.deliver?(:in_app)
  end

  def telegram?
    preference.present? && preference.deliver?(:telegram)
  end

  def telegram_body
    return telegram_text if telegram_text.present?

    link = absolute_url && %(<a href="#{absolute_url}">#{LINK_LABEL}</a>)
    [CGI.escapeHTML(message.to_s), link].compact.join("\n\n")
  end

  # В Telegram уезжает ссылка, по которой кликают с телефона, поэтому путь надо
  # достроить до абсолютного. На проде хост и https берутся из
  # routes.default_url_options, в разработке их нет — отсюда запасные значения.
  def absolute_url
    return @absolute_url if defined?(@absolute_url)

    @absolute_url =
      if url.blank?
        nil
      elsif url.to_s.start_with?('http')
        url
      else
        options = Rails.application.routes.default_url_options
        host = options[:host].presence || ENV['SERVER_HOST'].presence || 'localhost:3000'
        protocol = (options[:protocol].presence || 'http').to_s
        "#{protocol}://#{host}#{url}"
      end
  end
end
