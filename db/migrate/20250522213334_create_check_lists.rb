class CreateCheckLists < ActiveRecord::Migration[5.1]
  def change
    create_table :check_lists do |t|
      t.string :name, null: false
      t.text :description
      t.string :entity_type, null: false
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :check_lists, :entity_type
    add_index :check_lists, :active
  end
end
