class CreateDutyScheduleEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :duty_schedule_entries do |t|
      t.references :department, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.date :date, null: false
      t.references :assigned_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :duty_schedule_entries, %i[department_id user_id date], unique: true, name: 'index_duty_schedule_entries_uniqueness'
  end
end
