# frozen_string_literal: true

class SeedRestoringPauseReason < ActiveRecord::Migration[5.1]
  RESTORING = { code: 'restoring', name: 'На восстановлении/обновлении', position: 7 }.freeze

  def up
    RepairPauseReason.find_or_create_by!(code: RESTORING[:code]) do |r|
      r.name     = RESTORING[:name]
      r.position = RESTORING[:position]
    end
  end

  def down
    RepairPauseReason.where(code: RESTORING[:code]).delete_all
  end
end
