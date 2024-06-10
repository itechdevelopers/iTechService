class AddRememberPauseToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :remember_pause, :boolean, default: false, null: false
  end
end
