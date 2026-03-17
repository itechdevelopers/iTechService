class AddDesignSettingsToScheduleGroups < ActiveRecord::Migration[5.1]
  def change
    add_column :schedule_groups, :design_settings, :jsonb, default: {}, null: false
  end
end
