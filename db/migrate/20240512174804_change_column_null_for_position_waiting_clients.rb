class ChangeColumnNullForPositionWaitingClients < ActiveRecord::Migration[5.1]
  def change
    change_column_null :waiting_clients, :position, true
  end
end
