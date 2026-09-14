class CreateIphoneSalesImports < ActiveRecord::Migration[5.1]
  def change
    create_table :iphone_sales_imports do |t|
      t.string :delivery_id, null: false
      t.date :period_from, null: false
      t.date :period_to, null: false
      t.datetime :calculated_at, null: false
      t.string :methodology_version, null: false
      t.string :status, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :iphone_sales_imports, :delivery_id, unique: true
    add_index :iphone_sales_imports, [:status, :calculated_at]
  end
end
