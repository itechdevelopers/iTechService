# frozen_string_literal: true

# Single entry point for sending an employee a personal Telegram message.
# Reusable by any feature that needs to notify a staff member directly.
#
#   NotifyEmployee.call(user: some_user, text: '<b>Готово</b>')
#
# `text` is passed through as HTML (parse_mode: 'HTML'), so callers are
# responsible for escaping user-supplied fragments with CGI.escapeHTML —
# same convention as the existing Telegram jobs.
#
# For async delivery use NotifyEmployeeJob instead of calling this directly.
class NotifyEmployee
  # Errors that mean the chat is permanently unreachable — we drop the
  # binding instead of retrying forever.
  UNREACHABLE_ERRORS = [
    Telegram::Bot::Forbidden, # bot blocked / user deactivated
    Telegram::Bot::NotFound   # chat not found
  ].freeze

  Result = Struct.new(:status) do
    def sent?
      status == :sent
    end
  end

  def self.call(**args)
    new(**args).call
  end

  def initialize(user:, text:)
    @user = user
    @text = text
  end

  def call
    return Result.new(:not_linked) unless @user&.telegram_linked?

    outcome = SendTelegramMessage.call(chat_id: @user.telegram_chat_id, text: @text)
    return Result.new(:sent) if outcome.success?

    if unreachable?(outcome.error)
      @user.unlink_telegram!
      Rails.logger.warn(
        "[NotifyEmployee] user ##{@user.id} unreachable (#{outcome.error.class}); telegram unlinked"
      )
      return Result.new(:unreachable)
    end

    Rails.logger.error("[NotifyEmployee] user ##{@user.id} send failed: #{outcome.result}")
    Result.new(:error)
  end

  private

  def unreachable?(error)
    UNREACHABLE_ERRORS.any? { |klass| error.is_a?(klass) }
  end
end
