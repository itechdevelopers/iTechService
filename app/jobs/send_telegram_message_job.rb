# frozen_string_literal: true

# Delivery of a message to a Telegram chat identified by chat_id — group chats
# addressed through ENV (TELEGRAM_*_CHAT_ID) or a TelegramChat record.
#
#   SendTelegramMessageJob.perform_later(chat_id, '<b>Конфликт в графике</b>')
#
# The counterpart for personal messages is NotifyEmployeeJob. They are separate
# on purpose: NotifyEmployee resolves the chat from user.telegram_linked? and
# unlinks the account when Telegram answers Forbidden — correct for an employee
# who blocked the bot, wrong for a group chat, where there is no binding to drop.
#
# Why a job at all: SendTelegramMessage catches every error and returns an
# object, so a caller that ignores the result cannot tell a delivered message
# from a lost one, and retry_on never gets an exception to work with. Here the
# transient failures become exceptions again and are retried.
class SendTelegramMessageJob < ApplicationJob
  queue_as :default

  # A block is required: without one ActiveJob re-raises after the last attempt
  # and Sidekiq starts its own 25-attempt cycle spanning weeks. A notification
  # delivered days late is worse than none, so we log and stop.
  SendTelegramMessage::TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 4 do |job, error|
      # error_label, not error.message: on Rails 5.1 this argument is the
      # exception class (see ApplicationJob#error_label).
      Rails.logger.error(
        "[SendTelegramMessageJob] giving up for chat #{job.arguments.first}: " \
        "#{job.send(:error_label, error)}"
      )
    end
  end

  def perform(chat_id, text)
    return if chat_id.blank?

    outcome = SendTelegramMessage.call(chat_id: chat_id, text: text)
    return if outcome.success? || outcome.error.nil?

    # Telegram's own refusals (bad chat_id, bot kicked from the group) are
    # permanent — retrying them would just repeat the same error four times.
    raise outcome.error if SendTelegramMessage.transient_error?(outcome.error)

    Rails.logger.error("[SendTelegramMessageJob] chat #{chat_id}: #{outcome.result}")
  end
end
