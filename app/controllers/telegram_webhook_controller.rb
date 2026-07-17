# frozen_string_literal: true

# Receives Telegram updates (webhook in production, poller in dev) and binds
# an employee's private chat to their User via the /start linking flow.
#
# Linking strategy (graceful degradation):
#   /start <token>  -> hard match by users.telegram_link_token (deep link)
#   /start          -> fallback match by users.telegram_username (from.username)
#
# Once linked, the employee can attach photos to a service job over chat.
# The entry point is the persistent "📷 Добавить фото" reply button, shown
# after linking and by the /photo command; only linked employees may proceed.
class TelegramWebhookController < Telegram::Bot::UpdatesController
  PHOTO_BUTTON = '📷 Добавить фото'

  def start!(token = nil, *)
    user = find_user(token)

    if user
      user.link_telegram!(from['id'])
      respond_with :message,
                   text: "✅ Готово! Профиль «#{user.short_name}» привязан. " \
                         'Теперь бот сможет присылать вам личные уведомления.',
                   reply_markup: photo_keyboard
    else
      respond_with :message,
                   text: '❌ Не удалось найти ваш профиль. Откройте свой профиль ' \
                         'в системе и нажмите «Подключить Telegram», либо укажите ' \
                         'корректный ник Telegram в профиле.'
    end
  end

  # /photo — (re)shows the entry button for adding photos to a job.
  def photo!(*)
    return respond_not_linked unless current_employee

    respond_with :message,
                 text: 'Нажмите кнопку ниже, чтобы добавить фото к работе.',
                 reply_markup: photo_keyboard
  end

  # Catches plain text messages, including taps on the reply button.
  def message(message)
    return unless message['text'] == PHOTO_BUTTON
    return respond_not_linked unless current_employee

    # Placeholder for cycle 2 (job selection). Confirms the interactive
    # plumbing and the linking gate work end to end.
    respond_with :message,
                 text: "Профиль: #{current_employee.short_name}. Выбор работы — скоро."
  end

  private

  def find_user(token)
    if token.present?
      User.find_by(telegram_link_token: token)
    elsif from && from['username'].present?
      User.active.find_by(telegram_username: from['username'])
    end
  end

  # Resolves the linked employee from the incoming chat. Nil when the chat
  # is not bound to any profile (the verification gate for photo upload).
  def current_employee
    @current_employee ||= User.find_by(telegram_chat_id: from['id'])
  end

  def respond_not_linked
    respond_with :message,
                 text: 'Сначала привяжите профиль: откройте свой профиль в системе ' \
                       'и нажмите «Подключить Telegram».'
  end

  def photo_keyboard
    { keyboard: [[{ text: PHOTO_BUTTON }]], resize_keyboard: true }
  end
end
