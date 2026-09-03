class AddNotifyLocationCodesToInventories < ActiveRecord::Migration[5.1]
  def change
    add_column :inventories, :notify_location_codes, :string, array: true, default: []
  end
end
