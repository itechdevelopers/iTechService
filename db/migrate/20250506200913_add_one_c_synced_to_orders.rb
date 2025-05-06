class AddOneCSyncedToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :one_c_synced, :boolean, default: false
  end
end
