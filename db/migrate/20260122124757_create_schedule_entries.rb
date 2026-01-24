class CreateScheduleEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :schedule_entries do |t|
      t.references :schedule_group, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.date :date, null: false
      t.references :department, foreign_key: true
      t.references :shift, foreign_key: true
      t.references :occupation_type, foreign_key: true

      t.timestamps
    end

    add_index :schedule_entries, %i[schedule_group_id user_id date],
              unique: true,
              name: 'index_schedule_entries_uniqueness'
    add_index :schedule_entries, :date
  end
end
