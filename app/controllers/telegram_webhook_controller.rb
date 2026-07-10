# frozen_string_literal: true

# Receives Telegram updates (webhook in production, poller in dev) and binds
# an employee's private chat to their User via the /start linking flow.
#
# Linking strategy (graceful degradation):
#   /start <token>  -> hard match by users.telegram_link_token (deep link)
#   /start          -> fallback match by users.telegram_username (from.username)
class TelegramWebhookController < Telegram::Bot::UpdatesController
  def start!(token = nil, *)
    user = find_user(token)

    if user
      user.link_telegram!(from['id'])
      respond_with :message,
                   text: "✅ Готово! Профиль «#{user.short_name}» привязан. " \
                         'Теперь бот сможет присылать вам личные уведомления.'
    else
      respond_with :message,
                   text: '❌ Не удалось найти ваш профиль. Откройте свой профиль ' \
                         'в системе и нажмите «Подключить Telegram», либо укажите ' \
                         'корректный ник Telegram в профиле.'
    end
  end

  private

  def find_user(token)
    if token.present?
      User.find_by(telegram_link_token: token)
    elsif from && from['username'].present?
      User.active.find_by(telegram_username: from['username'])
    end
  end
end
