# frozen_string_literal: true

class SeedRepairPauseReasonCodes < ActiveRecord::Migration[5.1]
  EXISTING = [
    { name: 'Ждём запчасть',       code: 'waiting_part' },
    { name: 'Ждём согласования',   code: 'waiting_approval' },
    { name: 'Нужен другой мастер', code: 'other_master' }
  ].freeze

  URGENT = { code: 'urgent_repair', name: 'Срочный ремонт', position: 4 }.freeze

  def up
    EXISTING.each do |attrs|
      reason = RepairPauseReason.find_by(name: attrs[:name])
      reason&.update_column(:code, attrs[:code])
    end

    RepairPauseReason.find_or_create_by!(code: URGENT[:code]) do |r|
      r.name     = URGENT[:name]
      r.position = URGENT[:position]
    end
  end

  def down
    RepairPauseReason.where(code: URGENT[:code]).delete_all
    RepairPauseReason.where(code: EXISTING.map { |a| a[:code] })
                     .update_all(code: nil)
  end
end
