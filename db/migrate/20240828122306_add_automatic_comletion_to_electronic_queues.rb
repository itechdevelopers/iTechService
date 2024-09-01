class AddAutomaticComletionToElectronicQueues < ActiveRecord::Migration[5.1]
  def change
    add_column :electronic_queues, :automatic_completion, :string
    add_column :waiting_clients, :completed_automatically, :boolean, null: false, default: false
  end
end
