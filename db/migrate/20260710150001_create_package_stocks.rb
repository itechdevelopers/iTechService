class CreatePackageStocks < ActiveRecord::Migration[5.1]
  def change
    create_table :package_stocks do |t|
      t.references :package_design, foreign_key: true, null: false

      t.integer :size,                null: false          # enum: small/medium/large
      t.integer :boxes_count,         null: false, default: 0  # отслеживаемый остаток (коробки)
      t.integer :per_box_count,       null: false, default: 0
      t.integer :low_stock_threshold                       # порог дозаказа, задаёт админ (nullable)

      t.timestamps
    end

    # Одна строка на пару дизайн+размер (как в исходной гугл-табличке).
    add_index :package_stocks, %i[package_design_id size], unique: true
  end
end
