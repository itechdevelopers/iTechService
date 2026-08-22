class AddShowInMovementActsToStores < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :show_in_movement_acts, :boolean, default: false, null: false
  end
end
