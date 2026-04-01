class AddColorToLocations < ActiveRecord::Migration[5.1]
  def change
    add_column :locations, :color, :string
  end
end
