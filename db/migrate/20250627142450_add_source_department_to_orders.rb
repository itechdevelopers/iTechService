class AddSourceDepartmentToOrders < ActiveRecord::Migration[5.1]
  def change
    add_reference :orders, :source_department, foreign_key: { to_table: :departments }
    
    # Populate existing orders with department from their source store
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE orders 
          SET source_department_id = (
            SELECT department_id 
            FROM stores 
            WHERE stores.id = orders.source_store_id
          ) 
          WHERE source_store_id IS NOT NULL
        SQL
      end
    end
  end
end
