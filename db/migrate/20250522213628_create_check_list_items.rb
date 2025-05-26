class CreateCheckListItems < ActiveRecord::Migration[5.1]
  def change
    create_table :check_list_items do |t|
      t.references :check_list, null: false, foreign_key: true
      t.text :question, null: false
      t.boolean :required, default: false
      t.integer :position, null: false
      t.timestamps
    end

    add_index :check_list_items, [:check_list_id, :position], unique: true
  end
end
