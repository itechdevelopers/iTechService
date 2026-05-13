# frozen_string_literal: true

class BackfillRepairStatusForWaitingJobs < ActiveRecord::Migration[5.1]
  def up
    waiting = RepairStatus.find_by!(code: 'waiting')
    now = Time.zone.now

    repair_location_ids = Location.where("code LIKE ?", "repair%").pluck(:id)
    scope = ServiceJob.where(repair_status_id: nil, location_id: repair_location_ids)

    say_with_time "Backfilling repair_status='waiting' for #{scope.count} ServiceJobs" do
      scope.find_each do |sj|
        ServiceJob.transaction do
          RepairStatusChange.create!(
            service_job: sj,
            from_status_id: nil,
            to_status: waiting,
            user_id: nil,
            changed_at: now
          )
          sj.update_columns(
            repair_status_id: waiting.id,
            repair_status_changed_at: now,
            updated_at: now
          )
        end
      end
    end
  end

  def down
    say "Backfill is one-way; no rollback (would not know which markers were created by this migration)."
  end
end
