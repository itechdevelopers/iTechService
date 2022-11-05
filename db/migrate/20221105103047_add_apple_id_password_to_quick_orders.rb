class AddAppleIdPasswordToQuickOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :quick_orders, :apple_id_password, :string
  end
end
