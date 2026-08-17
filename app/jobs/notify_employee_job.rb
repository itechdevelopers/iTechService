# frozen_string_literal: true

# Async wrapper around NotifyEmployee — and the single place where a personal
# Telegram message gets retried. Features enqueue this instead of calling
# SendTelegramMessage inline:
#
#   NotifyEmployeeJob.perform_later(user.id, '<b>Заявка обновлена</b>')
#
# Why a job and not a service: SendTelegramMessage catches every error and
# returns an object, so an inline caller that ignores the return value loses
# the message without a trace — a webhook-side timeout to api.telegram.org was
# enough to drop a reminder for good. Here the failure becomes an exception
# again, retry_on gets its turn, and the caller stays free of network concerns.
class NotifyEmployeeJob < ApplicationJob
  queue_as :default

  # Same classes SendTelegramMessage recognises as transient; the decision to
  # act on them lives here, not in the service (see its TRANSIENT_ERRORS note).
  # A block is required: without one ActiveJob re-raises after the last attempt
  # and Sidekiq starts its own 25-attempt cycle spanning weeks. A reminder
  # delivered three days late is worse than none, so we log and stop — the
  # in-app bell has already covered the employee by then.
  SendTelegramMessage::TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 4 do |job, error|
      # error_label, not error.message: on Rails 5.1 this argument is the
      # exception class (see ApplicationJob#error_label).
      Rails.logger.error(
        "[NotifyEmployeeJob] giving up for user ##{job.arguments.first}: " \
        "#{job.send(:error_label, error)}"
      )
    end
  end

  def perform(user_id, text)
    user = User.find_by(id: user_id)
    return unless user

    result = NotifyEmployee.call(user: user, text: text)
    return if result.sent? || result.error.nil?

    # Permanent refusals (bot blocked, chat gone) are already handled inside
    # NotifyEmployee, which unlinks the account — nothing to retry there.
    raise result.error if SendTelegramMessage.transient_error?(result.error)
  end
end
