# frozen_string_literal: true

class SeedRepairStatusSetting < ActiveRecord::Migration[5.1]
  def up
    RepairStatusSetting.find_or_create_by!(id: 1) do |s|
      s.attention_timeout_seconds  = 300
      s.escalation_timeout_seconds = 3600
    end
  end

  def down
    RepairStatusSetting.where(id: 1).delete_all
  end
end
