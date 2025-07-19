class RemoveOneCSyncedFromOrders < ActiveRecord::Migration[5.1]
  def up
    # Verify that all orders have corresponding OrderExternalSync records
    orders_without_sync = Order.left_joins(:external_syncs)
                              .where(order_external_syncs: { id: nil })
                              .count
    
    if orders_without_sync > 0
      raise "Cannot remove one_c_synced column: #{orders_without_sync} orders without OrderExternalSync records"
    end
    
    remove_column :orders, :one_c_synced
  end
  
  def down
    add_column :orders, :one_c_synced, :boolean, default: false, null: false
    
    # Restore one_c_synced values based on OrderExternalSync records
    Order.joins(:one_c_sync).where(order_external_syncs: { sync_status: 2 }).update_all(one_c_synced: true)
  end
end
