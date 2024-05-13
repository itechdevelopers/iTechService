class AddReferenceFromUserToElqueueWindows < ActiveRecord::Migration[5.1]
  def up
    remove_column :users, :elqueue_window_id
    add_reference :users, :elqueue_window, foreign_key: true
  end

  def down
    remove_reference :users, :elqueue_window
    add_column :users, :elqueue_window_id, :integer, null: true
  end
end
