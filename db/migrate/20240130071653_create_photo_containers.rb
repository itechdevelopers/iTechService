class CreatePhotoContainers < ActiveRecord::Migration[5.1]
  def change
    create_table :photo_containers do |t|
      t.timestamps
    end

    add_reference :service_jobs, :photo_container, foreign_key: true
    add_column :photo_containers, :reception_photos, :string, array: true, default: []
    add_column :photo_containers, :in_operation_photos, :string, array: true, default: []
    add_column :photo_containers, :completed_photos, :string, array: true, default: []

    add_column :photo_containers, :reception_photos_meta_data, :string, array: true, default: []
    add_column :photo_containers, :in_operation_photos_meta_data, :string, array: true, default: []
    add_column :photo_containers, :completed_photos_meta_data, :string, array: true, default: []
  end
end
