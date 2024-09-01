class ScheduleAutomaticCompletionJob < ApplicationJob
  queue_as :default

  def perform
    ElectronicQueue.where(enabled: true).where.not(automatic_completion: [nil, '']).each do |queue|
      hours, minutes = queue.automatic_completion.split(':').map(&:to_i)

      execution_time = Time.zone.now.change(hour: hours, min: minutes)
      execution_time += 1.day if execution_time < Time.zone.now

      CompleteUnfinishedTicketsJob.set(wait_until: execution_time).perform_later(queue.id)
    end
  end
end
