class AddIsSeniorToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :is_senior, :boolean, default: false
  end
end
