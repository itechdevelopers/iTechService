class CreateMerits < ActiveRecord::Migration[5.1]
  def change
    create_table :merits do |t|
      t.references :recipient, foreign_key: { to_table: :users }, index: true
      t.references :issued_by, foreign_key: { to_table: :users }, index: true
      t.text :comment, null: false
      t.date :date
      t.boolean :exchanged, default: false, null: false
      t.datetime :exchanged_at
      t.references :fault, foreign_key: true, index: true

      t.timestamps
    end
  end
end
