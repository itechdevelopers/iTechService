class AddIndexesToImportedSales < ActiveRecord::Migration[5.1]
  def change
    add_index :imported_sales, :serial_number
    add_index :imported_sales, :imei
    add_index :imported_sales, :sold_at
    add_index :imported_sales, :quantity
  end
end
