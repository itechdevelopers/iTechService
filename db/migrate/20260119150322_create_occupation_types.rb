class CreateOccupationTypes < ActiveRecord::Migration[5.1]
  def change
    create_table :occupation_types do |t|
      t.references :city, foreign_key: true, null: false
      t.string :name, null: false
      t.string :color, limit: 7
      t.boolean :counts_as_working, default: false
      t.integer :position, default: 0

      t.timestamps
    end
    add_index :occupation_types, [:city_id, :position]
  end
end
