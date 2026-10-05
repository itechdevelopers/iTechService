# frozen_string_literal: true
class McpWrite < ApplicationRecord
  belongs_to :user
  after_commit :dispatch_outbox, on: [:create, :update]

  JOBS = {
    'gluing' => 'RepairGluingReminderJob',
    'testing_telegram' => 'SendTestingTelegramNotificationJob',
    'testing_in_app' => 'SendTestingInAppNotificationJob',
    'approval_telegram' => 'SendApprovalTelegramNotificationJob',
    'approval_in_app' => 'SendApprovalInAppNotificationJob'
  }.freeze

  # Only runs after the outer business transaction commits. The persisted outbox
  # also allows recovery after a process/Redis failure without repeating a write.
  def dispatch_outbox
    return if dispatched_at || outbox.empty? || outcome != 'succeeded'
    with_lock do
      return if dispatched_at
      outbox.each do |item|
        job = JOBS.fetch(item.fetch('kind')).constantize
        job = job.set(wait_until: Time.iso8601(item['run_at'])) if item['run_at']
        job.perform_later(item.fetch('id'))
      end
      update_columns(dispatched_at: Time.current)
    end
  rescue StandardError => e
    Rails.logger.error("[MCP] outbox pending write_id=#{id} error=#{e.class.name}")
  end
end
