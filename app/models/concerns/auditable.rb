module Auditable
  extend ActiveSupport::Concern

  included do
    after_save :update_audit_metadata, if: :should_audit_elqueue_work?
  end
  def should_audit_elqueue_work?
    @should_audit_elqueue_work ||= User.current&.able_to?('track_elqueue_work') && User.current&.serving_client?
  end

  def update_audit_metadata
    department_id = User.current.department_id
    audit_type = 'elqueue_work'
    ticket_id = User.current.elqueue_window.waiting_client.id
    audit = Audited::Audit.last
    audit.update(metadata: audit.metadata.merge(
      department_id: department_id,
      audit_type: audit_type,
      ticket_id: ticket_id
    ))
  end
end
