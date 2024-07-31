class CreateElqueueTicketMovements < ActiveRecord::Migration[5.1]
  def change
    create_table :elqueue_ticket_movements do |t|
      t.string :type
      t.references :waiting_client, null: false, foreign_key: true
      t.integer :old_position, null: true
      t.integer :new_position, null: true
      t.jsonb :queue_state, null: false, default: {}
      t.references :user, null: true
      t.integer :priority, null: true
      t.references :elqueue_window, null: true
      t.references :electronic_queue, null: false

      t.timestamps
    end

    add_index :elqueue_ticket_movements, :created_at
  end
end
