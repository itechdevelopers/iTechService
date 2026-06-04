class AddForTestingToLocations < ActiveRecord::Migration[5.1]
  def change
    add_column :locations, :for_testing, :boolean, default: false
    add_index :locations, :for_testing
  end
end
