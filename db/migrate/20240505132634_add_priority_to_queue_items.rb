class AddPriorityToQueueItems < ActiveRecord::Migration[5.1]
  def change
    add_column :queue_items, :priority, :integer, default: 0
  end
end
