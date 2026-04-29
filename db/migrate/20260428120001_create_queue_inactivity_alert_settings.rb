class CreateQueueInactivityAlertSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :queue_inactivity_alert_settings do |t|
      t.references :electronic_queue,
                   foreign_key: true,
                   null: false,
                   index: { unique: true, name: 'idx_qias_electronic_queue_id' }
      t.references :schedule_group,
                   foreign_key: true,
                   null: false,
                   index: { name: 'idx_qias_schedule_group_id' }
      t.integer :min_unattended_seconds, null: false

      t.timestamps
    end
  end
end
