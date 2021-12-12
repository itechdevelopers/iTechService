class AddArchiveToDepartment < ActiveRecord::Migration
  def change
    add_column :departments, :archive, :boolean, default: false
  end
end
