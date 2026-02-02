class AddRolesToTasks < ActiveRecord::Migration[5.1]
  def up
    add_column :tasks, :roles, :string, array: true, default: []

    # Migrate existing role data to roles array
    execute <<-SQL
      UPDATE tasks SET roles = ARRAY[role] WHERE role IS NOT NULL AND role != ''
    SQL
  end

  def down
    remove_column :tasks, :roles
  end
end
