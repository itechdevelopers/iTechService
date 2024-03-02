class AddFixedMainMenuToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :fixed_main_menu, :boolean, default: false
  end
end
