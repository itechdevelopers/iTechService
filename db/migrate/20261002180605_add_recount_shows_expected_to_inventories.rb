class AddRecountShowsExpectedToInventories < ActiveRecord::Migration[5.1]
  def change
    add_column :inventories, :recount_shows_expected, :boolean, default: false, null: false
  end
end
