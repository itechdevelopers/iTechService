class AddArchivedToQueueItem < ActiveRecord::Migration[5.1]
  def change
    add_column :queue_items, :archived, :boolean, default: false
  end
end
