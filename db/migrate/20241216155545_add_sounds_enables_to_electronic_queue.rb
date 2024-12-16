class AddSoundsEnablesToElectronicQueue < ActiveRecord::Migration[5.1]
  def change
    add_column :electronic_queues, :sounds_enabled, :boolean, default: false
  end
end
