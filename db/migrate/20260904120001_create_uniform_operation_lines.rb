class CreateUniformOperationLines < ActiveRecord::Migration[5.1]
  def change
    create_table :uniform_operation_lines do |t|
      t.references :uniform_operation, null: false, foreign_key: true
      t.references :uniform_stock,     null: false, foreign_key: true

      # Всегда положительное: направление задаёт kind документа.
      t.integer :quantity, null: false

      t.timestamps
    end
  end
end
