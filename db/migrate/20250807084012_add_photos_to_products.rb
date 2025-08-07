class AddPhotosToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :photos, :string, array: true, default: []
    add_column :products, :photos_meta_data, :string, array: true, default: []
  end
end
