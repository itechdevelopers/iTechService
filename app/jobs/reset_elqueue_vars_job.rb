class ResetElqueueVarsJob < ApplicationJob
  queue_as :default
  def perform
    QueueItem.update_all(last_ticket_number: 0)
    User.reset_windows
  end
end