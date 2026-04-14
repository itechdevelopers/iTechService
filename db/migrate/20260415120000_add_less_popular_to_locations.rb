class AddLessPopularToLocations < ActiveRecord::Migration[5.1]
  def change
    add_column :locations, :less_popular, :boolean, default: false
  end
end
