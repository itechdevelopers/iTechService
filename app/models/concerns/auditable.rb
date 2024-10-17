module Auditable
  extend ActiveSupport::Concern

  included do
    after_save :update_audit_metadata
  end
  def should_audit_elqueue_work?
    User.current&.serving_client?
  end

  def should_audit_technician?
    User.current&.role == 'technician'
  end

  def update_audit_metadata
    department_id = User.current&.department_id
    audit = Audited::Audit.last

    if should_audit_elqueue_work?
      audit.update(metadata: audit.metadata.merge(
        department_id: department_id,
        audit_type: 'elqueue_work',
        ticket_id: User.current.elqueue_window.waiting_client.id
      ))
    elsif should_audit_technician?
      audit.update(metadata: audit.metadata.merge(
        department_id: department_id,
        audit_type: 'technician_work'
      ))
    else
      audit.update(metadata: audit.metadata.merge(
        department_id: department_id,
        audit_type: 'tracked_work'
      ))
    end
  end
end
