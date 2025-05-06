class AddSourceStoreToOrders < ActiveRecord::Migration[5.1]
  def change
    add_reference :orders, :source_store, foreign_key: { to_table: :stores }, index: true
  end
end
