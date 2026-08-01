class CreateJoinTableOccupationTypesQueueInactivityAlertSettings < ActiveRecord::Migration[5.1]
  def change
    create_join_table :occupation_types, :queue_inactivity_alert_settings do |t|
      t.index %i[queue_inactivity_alert_setting_id occupation_type_id],
              unique: true,
              name: 'idx_qias_occupation_types_unique'
      t.index :occupation_type_id, name: 'idx_qias_occupation_types_occ_type_id'
    end
  end
end
