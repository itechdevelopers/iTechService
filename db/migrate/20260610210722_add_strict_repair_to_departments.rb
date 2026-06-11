class AddStrictRepairToDepartments < ActiveRecord::Migration[5.1]
  def change
    add_column :departments, :strict_repair, :boolean, default: false, null: false
  end
end
