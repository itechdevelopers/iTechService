class CreateScheduleWeekSnapshots < ActiveRecord::Migration[5.1]
  def change
    create_table :schedule_week_snapshots do |t|
      t.references :schedule_group, foreign_key: true
      t.date :week_start, null: false
      t.datetime :saved_at, null: false

      t.timestamps
    end

    add_index :schedule_week_snapshots, %i[schedule_group_id week_start], unique: true, name: 'idx_snapshots_group_week'
  end
end
