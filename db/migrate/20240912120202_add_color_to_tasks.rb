class AddColorToTasks < ActiveRecord::Migration[5.1]
  def change
    add_column :tasks, :color, :string, default: ''
  end
end
