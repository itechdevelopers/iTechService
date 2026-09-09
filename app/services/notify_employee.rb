# frozen_string_literal: true

# Single entry point for sending an employee a personal Telegram message.
# Reusable by any feature that needs to notify a staff member directly.
#
#   NotifyEmployee.call(user: some_user, text: '<b>Готово</b>')
#   NotifyEmployee.call(user: some_user, text: '<b>Готово</b>', photo_path: path)
#
# `text` is passed through as HTML (parse_mode: 'HTML'), so callers are
# responsible for escaping user-supplied fragments with CGI.escapeHTML —
# same convention as the existing Telegram jobs.
#
# With `photo_path` the same text goes out as the photo caption — one message
# and one push instead of two.
#
# For async delivery use NotifyEmployeeJob instead of calling this directly.
class NotifyEmployee
  # Errors that mean the chat is permanently unreachable — we drop the
  # binding instead of retrying forever.
  UNREACHABLE_ERRORS = [
    Telegram::Bot::Forbidden, # bot blocked / user deactivated
    Telegram::Bot::NotFound   # chat not found
  ].freeze

  # `error` carries the exception SendTelegramMessage caught, so a caller that
  # wants to retry (NotifyEmployeeJob) can tell a network hiccup from a
  # permanent refusal. nil on every status except :error.
  Result = Struct.new(:status, :error) do
    def sent?
      status == :sent
    end
  end

  def self.call(**args)
    new(**args).call
  end

  # Подпись к фото у Telegram ограничена 1024 символами; более длинный текст
  # API отвергает целиком, поэтому такое уведомление уходит текстом без
  # картинки — потерять картинку дешевле, чем сообщение.
  CAPTION_LIMIT = 1024

  def initialize(user:, text:, photo_path: nil)
    @user = user
    @text = text
    @photo_path = photo_path
  end

  def call
    return Result.new(:not_linked) unless @user&.telegram_linked?

    outcome = deliver
    return Result.new(:sent) if outcome.success?

    if unreachable?(outcome.error)
      @user.unlink_telegram!
      Rails.logger.warn(
        "[NotifyEmployee] user ##{@user.id} unreachable (#{outcome.error.class}); telegram unlinked"
      )
      return Result.new(:unreachable)
    end

    Rails.logger.error("[NotifyEmployee] user ##{@user.id} send failed: #{outcome.result}")
    Result.new(:error, outcome.error)
  end

  private

  def deliver
    return send_text unless photo?

    SendTelegramPhoto.call(
      chat_id: @user.telegram_chat_id,
      file_path: @photo_path,
      caption: @text
    )
  end

  def send_text
    SendTelegramMessage.call(chat_id: @user.telegram_chat_id, text: @text)
  end

  # Путь приходит из релиза приложения и может не существовать, если джоба
  # пережила выкладку: без картинки уведомление всё равно должно дойти.
  def photo?
    return false if @photo_path.blank?
    return false if @text.to_s.length > CAPTION_LIMIT

    return true if File.exist?(@photo_path)

    Rails.logger.warn("[NotifyEmployee] photo not found: #{@photo_path}; sending text only")
    false
  end

  def unreachable?(error)
    UNREACHABLE_ERRORS.any? { |klass| error.is_a?(klass) }
  end
end
