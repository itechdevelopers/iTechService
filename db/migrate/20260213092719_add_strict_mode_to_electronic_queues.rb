class AddStrictModeToElectronicQueues < ActiveRecord::Migration[5.1]
  def change
    add_column :electronic_queues, :strict_mode, :boolean, default: false, null: false
  end
end
