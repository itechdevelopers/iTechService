class AddMinUnattendedSecondsToElectronicQueues < ActiveRecord::Migration[5.1]
  def change
    add_column :electronic_queues, :min_unattended_seconds, :integer
  end
end
