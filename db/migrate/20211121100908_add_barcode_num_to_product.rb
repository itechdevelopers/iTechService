class AddBarcodeNumToProduct < ActiveRecord::Migration
  def change
    add_column :products, :barcode_num, :string
    add_index :products, :barcode_num
  end
end
