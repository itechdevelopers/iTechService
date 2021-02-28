class AddCanHelpInMacServiceToUsers < ActiveRecord::Migration
  def change
    add_column :users, :can_help_in_mac_service, :boolean, default: false
  end
end
