# frozen_string_literal: true

class CreateTimeBankEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :time_bank_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :schedule_group, null: false, foreign_key: true
      t.references :event_type, null: false, foreign_key: { to_table: :time_bank_event_types }
      t.string :direction, null: false
      t.integer :minutes, null: false
      t.date :occurred_on, null: false
      t.time :debit_start_time
      t.time :debit_end_time
      t.text :note
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :time_bank_entries, %i[user_id direction]
    add_index :time_bank_entries, :occurred_on
  end
end
