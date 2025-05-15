class UpdateNewToCurrentOrderStatuses < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      UPDATE orders
      SET status = 'current'
      WHERE status IN ('new', 'pending');
    SQL
  end

  def down
    puts "Warning: Can't revert status changes from 'current' back to original values"
  end
end
