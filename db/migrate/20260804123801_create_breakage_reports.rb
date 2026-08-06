class CreateBreakageReports < ActiveRecord::Migration[5.1]
  def change
    create_table :breakage_reports do |t|
      t.references :service_job, null: false, foreign_key: true, index: true
      t.references :device_task, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.references :item, foreign_key: true, index: true
      t.decimal :part_price, precision: 10, scale: 2
      t.text :circumstances, null: false
      t.text :resolution

      t.timestamps
    end

    add_column :photo_containers, :breakage_photos, :string, array: true, default: []
    add_column :photo_containers, :breakage_photos_meta_data, :string, array: true, default: []
  end
end
