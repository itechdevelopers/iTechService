# frozen_string_literal: true
module ServiceJobs
  # Shared by the UI and MCP. Callers authorize/validate intent, then enqueue
  # notifications after their outer transaction commits.
  class RepairStatusTransition
    def self.call(service_job:, status:, user:, pause_reason: nil, displaced_by: nil,
                  gluing_hours: nil, testing_target: nil, what_to_test: nil, approval_question: nil)
      ServiceJob.transaction do
        change = service_job.change_repair_status!(status, user: user, pause_reason: pause_reason,
          displaced_by: displaced_by, gluing_hours: gluing_hours)
        testing = if pause_reason&.testing?
          service_job.testing_sessions.create!(sender: user, target_location: testing_target, what_to_test: what_to_test)
        end
        approval = if pause_reason&.waiting_approval?
          service_job.approval_requests.create!(requester: user, question: approval_question)
        end
        {change: change, testing: testing, approval: approval}
      end
    end
  end
end
