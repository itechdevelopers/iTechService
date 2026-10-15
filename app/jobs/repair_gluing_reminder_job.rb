# Задачи этого класса ещё могут стоять в отложенной очереди Sidekiq: так
# планировалась проклейка, пока срок не стал общим для всех пауз. Всё, что
# происходит по сроку, теперь делает RepairPauseExpiryJob.
class RepairGluingReminderJob < ApplicationJob
  queue_as :default

  def perform(change_id)
    RepairPauseExpiryJob.perform_now(change_id)
  end
end
