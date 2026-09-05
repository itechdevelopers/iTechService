class CreateUniformOperations < ActiveRecord::Migration[5.1]
  def change
    create_table :uniform_operations do |t|
      t.string     :kind,         null: false # UniformOperation::KINDS
      t.references :author,       null: false, foreign_key: { to_table: :users } # кто оформил
      t.references :recipient,    foreign_key: { to_table: :users } # сотрудник: выдача, возврат, списание с рук
      t.text       :comment
      t.date       :performed_on, null: false

      t.timestamps
    end

    add_index :uniform_operations, :kind
  end
end
