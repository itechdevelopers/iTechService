# frozen_string_literal: true

module Bot
  # Strict allowlist representation of a ServiceJob for the external bot.
  class ServiceJobStatusPresenter
    def initialize(service_job)
      @service_job = service_job
    end

    def as_json
      {
        ticket_number: @service_job.ticket_number,
        device: { name: @service_job.type_name },
        received_at: @service_job.received_at,
        expected_return_at: @service_job.return_at,
        completed_at: @service_job.done_at,
        ready_at: nil,
        repair_status: repair_status_json,
        repair_completed: repair_completed?,
        ready_for_pickup: @service_job.at_done? == true,
        actual_cost: decimal(@service_job.tasks_cost),
        branch: branch_json
      }
    end

    private

    def repair_status_json
      status = @service_job.repair_status
      status ? { code: status.code, name: status.name } : nil
    end

    def repair_completed?
      @service_job.repair_status&.completed? == true
    end

    def branch_json
      department = @service_job.department
      return nil unless department

      { id: department.id, name: department.name, city: department.city_name }
    end

    def decimal(value)
      value&.to_d&.to_s('F')
    end
  end
end
