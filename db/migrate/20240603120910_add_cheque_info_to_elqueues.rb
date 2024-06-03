class AddChequeInfoToElqueues < ActiveRecord::Migration[5.1]
  def change
    add_column :electronic_queues, :check_info, :string, default: ""
  end
end
