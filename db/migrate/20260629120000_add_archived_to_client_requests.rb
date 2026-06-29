class AddArchivedToClientRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :client_requests, :archived, :boolean, default: false, null: false
    add_index :client_requests, :archived
  end
end
