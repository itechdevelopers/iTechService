class ChangeWindowsTypeInQueueItems < ActiveRecord::Migration[5.1]
  def up
    add_column :queue_items, :windows_array, :integer, array: true, default: []

    QueueItem.find_each do |item|
      if item.windows.present?
        numbers = item.windows.scan(/\d+/).map(&:to_i)
        item.update_column(:windows_array, numbers)
      end
    end

    remove_column :queue_items, :windows
    rename_column :queue_items, :windows_array, :windows
    add_column :queue_items, :redirect_windows, :integer, array: true, default: []
  end

  def down
    add_column :queue_items, :windows_string, :string
    QueueItem.find_each do |item|
      item.update_column(:windows_string, item.windows.join(', ')) if item.windows.present?
    end

    remove_column :queue_items, :windows
    rename_column :queue_items, :windows_string, :windows
    remove_column :queue_items, :redirect_windows
  end
end
