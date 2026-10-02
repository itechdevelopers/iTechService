class AddDropdownStyleToTasks < ActiveRecord::Migration[5.1]
  def change
    add_column :tasks, :emoji, :string
    add_column :tasks, :bold, :boolean, default: false, null: false
    add_column :tasks, :row_size, :integer, default: 0, null: false
  end
end
