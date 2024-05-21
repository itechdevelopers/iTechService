class DeleteClientNameFromWaitingClients < ActiveRecord::Migration[5.1]
  def up
    remove_column :waiting_clients, :client_name
  end

  def down
    add_column :waiting_clients, :client_name, :string
  end
end
