class UserNeedToSelectWindow < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :need_to_select_window, :boolean, default: false
  end
end
