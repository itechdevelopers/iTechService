class AddUnattendedTrackingToWaitingClients < ActiveRecord::Migration[5.1]
  def change
    add_column :waiting_clients, :unattended_started_at, :datetime
    add_column :waiting_clients, :unattended_duration_seconds, :integer
  end
end
