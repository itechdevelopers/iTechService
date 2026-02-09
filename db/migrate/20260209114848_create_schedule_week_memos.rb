class CreateScheduleWeekMemos < ActiveRecord::Migration[5.1]
  def change
    create_table :schedule_week_memos do |t|
      t.references :schedule_group, foreign_key: true
      t.date :week_start, null: false
      t.text :content, null: false, default: ''
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :schedule_week_memos, %i[schedule_group_id week_start], name: 'idx_memos_group_week'
  end
end
