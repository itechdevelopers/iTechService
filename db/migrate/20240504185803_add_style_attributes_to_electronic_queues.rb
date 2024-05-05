class AddStyleAttributesToElectronicQueues < ActiveRecord::Migration[5.1]
  def change
    add_column :electronic_queues, :header_boldness, :integer, default: 600
    add_column :electronic_queues, :header_font_size, :integer, default: 24
    add_column :electronic_queues, :annotation_boldness, :integer, default: 400
    add_column :electronic_queues, :annotation_font_size, :integer, default: 18
  end
end
