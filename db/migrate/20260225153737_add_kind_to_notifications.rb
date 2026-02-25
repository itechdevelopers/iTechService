class AddKindToNotifications < ActiveRecord::Migration[5.1]
  def change
    add_column :notifications, :kind, :string
  end
end
