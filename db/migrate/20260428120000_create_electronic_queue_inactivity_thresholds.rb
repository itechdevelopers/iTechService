class CreateElectronicQueueInactivityThresholds < ActiveRecord::Migration[5.1]
  def change
    create_table :electronic_queue_inactivity_thresholds do |t|
      t.references :electronic_queue,
                   foreign_key: true,
                   null: false,
                   index: { name: 'idx_eq_inactivity_thresholds_eq_id' }
      t.integer :total_on_shift, null: false
      t.integer :max_inactive, null: false

      t.timestamps
    end

    add_index :electronic_queue_inactivity_thresholds,
              %i[electronic_queue_id total_on_shift],
              unique: true,
              name: 'idx_eq_inactivity_thresholds_unique'
  end
end
