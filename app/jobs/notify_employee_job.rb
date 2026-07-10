# frozen_string_literal: true

# Async wrapper around NotifyEmployee. Future features enqueue this to send
# an employee a personal Telegram message off the request cycle:
#
#   NotifyEmployeeJob.perform_later(user.id, '<b>Заявка обновлена</b>')
class NotifyEmployeeJob < ApplicationJob
  queue_as :default

  def perform(user_id, text)
    user = User.find_by(id: user_id)
    return unless user

    NotifyEmployee.call(user: user, text: text)
  end
end
