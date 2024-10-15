class TrackedWorkReport < BaseReport
  def call
    @result = generate_elqueue_work_report
  end

  private

  def generate_elqueue_work_report
    audits = fetch_audits
    report_data = process_audits(audits)
    generate_report(report_data)
  end

  def fetch_audits
    Audited::Audit.where(created_at: period)
                  .where("metadata->>'audit_type' = ? AND metadata->>'department_id' = ?",'elqueue_work', department_id.to_s)
  end

  def process_audits(audits)
    audits.group_by(&:user_id).transform_values do |user_audits|
      user_audits.map do |audit|
        ElqueueAuditReport::StrategyFactory.process_audit(audit)
      end.compact
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
