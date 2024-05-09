class UpdateElqueueModels < ActiveRecord::Migration[5.1]
  def up
    remove_column :elqueue_windows, :user_id
    add_column :users, :elqueue_window_id, :integer, null: true
    add_column :queue_items, :last_ticket_number, :integer, null: true
    add_column :waiting_clients, :ticket_number, :string, null: false
    add_column :waiting_clients, :priority, :integer, null: false, default: 0


    ElectronicQueue.all.each do |elqueue|
      elqueue.create_elqueue_windows
    end
  end

  def down
    add_column :elqueue_windows, :user_id, :integer
    remove_column :users, :elqueue_window_id
    remove_column :queue_items, :last_ticket_number
    remove_column :waiting_clients, :ticket_number
    remove_column :waiting_clients, :priority
  end
end
