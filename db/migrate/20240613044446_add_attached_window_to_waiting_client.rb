class AddAttachedWindowToWaitingClient < ActiveRecord::Migration[5.1]
  def change
    add_column :waiting_clients, :attached_window, :integer
  end
end
