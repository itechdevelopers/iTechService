class AddPausedToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :paused, :boolean
  end
end
