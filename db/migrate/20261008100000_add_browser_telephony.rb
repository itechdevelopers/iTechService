class AddBrowserTelephony < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :telephony_extension, :string
    add_index :users, :telephony_extension, unique: true, where: "telephony_extension IS NOT NULL"
    add_column :users, :pbx_extension, :string
    add_index :users, :pbx_extension, unique: true, where: "pbx_extension IS NOT NULL"
    create_table :phone_calls do |t|
      t.string :call_unique_id, null: false
      t.datetime :started_at, null: false
      t.string :caller_number, null: false
      t.string :caller_employee_name
      t.references :caller_user, foreign_key: { to_table: :users }
      t.string :called_number
      t.string :answered_extension
      t.string :answered_employee_name
      t.references :answered_user, foreign_key: { to_table: :users }
      t.string :direction, null: false
      t.string :status, null: false
      t.integer :duration, null: false, default: 0
      t.integer :billsec, null: false, default: 0
      t.string :recording_path
      t.timestamps
    end
    add_index :phone_calls, :call_unique_id, unique: true
    add_index :phone_calls, [:started_at, :id]
    add_index :phone_calls, :caller_number
    Ability.find_or_create_by!(name: 'work_with_telephony') { |a| a.admin_assignable = true }
  end

  def down
    Ability.find_by(name: 'work_with_telephony')&.destroy
    drop_table :phone_calls
    remove_column :users, :pbx_extension
    remove_column :users, :telephony_extension
  end
end
