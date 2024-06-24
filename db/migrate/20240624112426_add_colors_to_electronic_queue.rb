class AddColorsToElectronicQueue < ActiveRecord::Migration[5.1]
  def change
    add_column :electronic_queues, :background_color, :string
    add_column :electronic_queues, :queue_item_color, :string
    add_column :electronic_queues, :back_button_color, :string
  end
end
