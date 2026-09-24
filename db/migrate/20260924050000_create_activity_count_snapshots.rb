class CreateActivityCountSnapshots < ActiveRecord::Migration[5.1]
  def change
    create_table :activity_count_imports do |t|
      t.string :metric, null: false
      t.string :delivery_id, null: false
      t.date :period_from, null: false
      t.date :period_to, null: false
      t.datetime :calculated_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :activity_count_imports, [:metric, :delivery_id], unique: true, name: 'activity_count_import_identity'
    create_table :activity_count_days do |t|
      t.string :metric, null: false
      t.date :date, null: false
      t.integer :quantity, null: false
      t.jsonb :branches, null: false, default: []
      t.references :activity_count_import, null: false, foreign_key: true, index: {name: 'activity_count_day_source'}
      t.timestamps
    end
    add_index :activity_count_days, [:metric, :date], unique: true
  end
end
