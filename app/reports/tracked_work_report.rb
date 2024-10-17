class TrackedWorkReport < BaseReport
  USER_TICKET_MOVEMENTS = %w[
    ElqueueTicketMovement::Called
    ElqueueTicketMovement::Manual
    ElqueueTicketMovement::Requeued
    ElqueueTicketMovement::RequeuedCompleted
  ].freeze

  def call
    @result = {}
    @result[:elqueue_work] = generate_elqueue_work_report
    @result[:technician_work] = generate_technician_work_report
    @result[:tracked_work] = generate_tracked_work_report
  end

  private

  def generate_tracked_work_report
    audits = fetch_tracked_work_audits
    report_data = process_audits(audits)
    generate_report(report_data)
  end

  def generate_technician_work_report
    audits = fetch_technician_audits
    report_data = process_audits(audits)
    generate_report(report_data)
  end

  def generate_elqueue_work_report
    audits = fetch_audits
    movements = fetch_movements

    report_data_audits = process_audits(audits)
    report_data_movements = process_movements(movements)

    report_data = merge_report_data(report_data_audits, report_data_movements)
    generate_report(report_data)
  end

  def fetch_audits
    Audited::Audit.where(created_at: period)
                  .where("metadata->>'audit_type' = ? AND metadata->>'department_id' = ?",'elqueue_work', department_id.to_s)
  end

  def fetch_technician_audits
    Audited::Audit.where(created_at: period)
                  .where("metadata->>'audit_type' = ? AND metadata->>'department_id' = ?", 'technician_work', department_id.to_s)
  end

  def fetch_tracked_work_audits
    Audited::Audit.where(created_at: period)
                  .where("metadata->>'audit_type' = ? AND metadata->>'department_id' = ?", 'tracked_work', department_id.to_s)
  end

  def fetch_movements
    elqueue_id = ElectronicQueue.where(department_id: department_id)&.last&.id
    ElqueueTicketMovement.where(created_at: period)
                         .where(type: USER_TICKET_MOVEMENTS,
                                electronic_queue_id: elqueue_id)
  end

  def process_audits(audits)
    audits.group_by(&:user_id).transform_values do |user_audits|
      user_audits.map do |audit|
        AuditReport::StrategyFactory.process_audit(audit)
      end.compact
    end
  end

  def process_movements(movements)
    movements.group_by(&:user_id).transform_values do |movements|
      movements.map do |movement|
        UserTicketMovementProcessor.process(movement)
      end
    end
  end

  def merge_report_data(report_data_audits, report_data_movements)
    merged_data = report_data_audits.deep_dup

    report_data_movements.each do |user_id, movements|
      if merged_data.key?(user_id)
        merged_data[user_id].concat(movements)
      else
        merged_data[user_id] = movements
      end
    end

    merged_data.transform_values do |actions|
      actions.sort_by { |action| action[:time] }
    end
  end

  def generate_report(report_data)
    {
      users: report_data.map do |user_id, audits|
        {
          user_id: user_id,
          audits: audits
        }
      end
    }
  end
end
