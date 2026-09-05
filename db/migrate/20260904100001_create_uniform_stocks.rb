class CreateUniformStocks < ActiveRecord::Migration[5.1]
  def change
    create_table :uniform_stocks do |t|
      t.references :uniform_kind, null: false, foreign_key: true

      t.string  :size,     null: false               # значение из UniformKind::SIZES
      t.integer :quantity, null: false, default: 0   # свободный остаток на складе

      t.timestamps
    end

    # Одна строка на пару «вид формы + размер»: она же галочка размера в форме вида.
    add_index :uniform_stocks, %i[uniform_kind_id size], unique: true
  end
end
