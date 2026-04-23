class AddArchivedToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :archived, :boolean, default: false, null: false
    add_index :products, :archived
  end
end
