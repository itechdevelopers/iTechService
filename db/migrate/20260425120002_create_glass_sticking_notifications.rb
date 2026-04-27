class CreateGlassStickingNotifications < ActiveRecord::Migration[5.1]
  def change
    create_table :glass_sticking_notifications do |t|
      t.references :sender, foreign_key: { to_table: :users }, null: false
      t.references :recipient, foreign_key: { to_table: :users }, null: false
      t.references :department, foreign_key: true, null: false
      t.integer :status, null: false

      t.timestamps
    end

    add_index :glass_sticking_notifications, %i[sender_id created_at], name: 'idx_glass_sticking_sender_created'
    add_index :glass_sticking_notifications, %i[department_id created_at], name: 'idx_glass_sticking_dept_created'
  end
end
