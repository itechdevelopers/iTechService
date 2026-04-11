class AddActiveToScheduleGroupMemberships < ActiveRecord::Migration[5.1]
  def change
    add_column :schedule_group_memberships, :active, :boolean, default: true, null: false
  end
end
