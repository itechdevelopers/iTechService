class RepairAttentionEscalationJob < ApplicationJob
  queue_as :default

  def perform(marker_id)
    marker = RepairAttentionMarker.find_by(id: marker_id)
    return unless marker
    return if marker.processed?
    return if marker.escalated_at.present?

    if status_changed?(marker)
      marker.mark_auto_resolved!
      return
    end

    RepairAttentionNotifier.call(marker)
    marker.update!(escalated_at: Time.zone.now)
  end

  private

  def status_changed?(marker)
    marker.service_job.repair_status_id != marker.status_at_view_id
  end
end
