class AddOrderDefaultsToUserSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :user_settings, :default_order_department_ids, :integer, array: true, default: []
    add_column :user_settings, :default_order_statuses, :string, array: true, default: []
  end
end
