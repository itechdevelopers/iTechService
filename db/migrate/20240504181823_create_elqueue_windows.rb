class CreateElqueueWindows < ActiveRecord::Migration[5.1]
  def change
    create_table :elqueue_windows do |t|
      t.references :user, null: true, foreign_key: true
      t.integer :window_number, null: false
      t.references :electronic_queue, null: false, foreign_key: true
      t.boolean :is_active, null: false, default: false

      t.timestamps
    end

    add_reference :waiting_clients, :elqueue_window, foreign_key: true, null: true
  end
end
