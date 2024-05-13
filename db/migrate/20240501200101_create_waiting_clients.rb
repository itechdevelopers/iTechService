class CreateWaitingClients < ActiveRecord::Migration[5.1]
  def change
    create_table :waiting_clients do |t|
      t.references :queue_item, foreign_key: true, null: false
      t.integer :position, null: false, default: 0
      t.string :phone_number
      t.string :client_name
      t.references :client, foreign_key: true
      t.datetime :ticket_issued_at
      t.datetime :ticket_called_at
      t.datetime :ticket_served_at
      t.string :status, null: false, default: 'waiting'

      t.timestamps
    end
  end
end
