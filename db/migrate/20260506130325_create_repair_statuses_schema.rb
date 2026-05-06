class CreateRepairStatusesSchema < ActiveRecord::Migration[5.1]
  def change
    create_table :repair_statuses do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :color, null: false, default: '#cccccc'
      t.integer :position, null: false, default: 0
      t.boolean :system, null: false, default: false
      t.timestamps
    end
    add_index :repair_statuses, :code, unique: true

    create_table :repair_pause_reasons do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :archived, null: false, default: false
      t.timestamps
    end

    add_reference :service_jobs, :repair_status, foreign_key: true, index: true
    add_reference :service_jobs, :repair_pause_reason, foreign_key: true, index: true
    add_column :service_jobs, :repair_status_changed_at, :datetime

    create_table :repair_status_changes do |t|
      t.references :service_job, null: false, foreign_key: true, index: true
      t.references :from_status, foreign_key: { to_table: :repair_statuses }
      t.references :to_status, null: false, foreign_key: { to_table: :repair_statuses }
      t.references :repair_pause_reason, foreign_key: true
      t.references :user, foreign_key: true
      t.datetime :changed_at, null: false
      t.timestamps
    end
    add_index :repair_status_changes, :changed_at
  end
end
