# frozen_string_literal: true

# Чинит работы, у которых repair_status застрял на in_progress|paused, хотя
# работа уже не на repair-локации и все задачи Ремонт закрыты. Возникало
# из-за гонки after_commit в DeviceTask с одновременной сменой локации
# в той же транзакции (см. fix в app/models/device_task.rb).
class ResyncStuckRepairStatuses < ActiveRecord::Migration[5.1]
  REPAIR_LOCATION_CODES = %w[repair repairmac repair_notebooks].freeze

  def up
    in_progress = RepairStatus.find_by(code: 'in_progress')
    paused      = RepairStatus.find_by(code: 'paused')
    completed   = RepairStatus.find_by(code: 'completed')
    return unless in_progress && paused && completed

    non_repair_loc_ids = Location.where.not(code: REPAIR_LOCATION_CODES).pluck(:id)

    candidates = ServiceJob.where(repair_status_id: [in_progress.id, paused.id], location_id: non_repair_loc_ids)

    fixed = 0
    candidates.find_each do |sj|
      has_open_repair_tasks = sj.device_tasks
                                .joins(task: :product)
                                .where('products.code LIKE ?', 'repair%')
                                .where(done: 0)
                                .exists?
      next if has_open_repair_tasks

      sj.change_repair_status!(completed, user: nil)
      fixed += 1
    end

    say "ResyncStuckRepairStatuses: fixed #{fixed} stuck service_jobs"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
