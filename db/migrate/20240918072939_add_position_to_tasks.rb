class AddPositionToTasks < ActiveRecord::Migration[5.1]
  def up
    add_column :tasks, :position, :integer

    Task.order(:created_at).each.with_index(1) do |task, index|
      task.update_column :position, index
    end

    change_column_null :tasks, :position, false
  end

  def down
    remove_column :tasks, :position
  end
end
