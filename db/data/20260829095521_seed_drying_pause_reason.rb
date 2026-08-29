# frozen_string_literal: true

class SeedDryingPauseReason < ActiveRecord::Migration[5.1]
  DRYING = { code: 'drying', name: 'Сушка устройства', position: 8 }.freeze

  def up
    RepairPauseReason.find_or_create_by!(code: DRYING[:code]) do |r|
      r.name     = DRYING[:name]
      r.position = DRYING[:position]
    end
  end

  def down
    RepairPauseReason.where(code: DRYING[:code]).delete_all
  end
end
