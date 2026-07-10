class CreatePackageDesigns < ActiveRecord::Migration[5.1]
  def change
    create_table :package_designs do |t|
      t.string :name,  null: false
      t.string :image  # CarrierWave (PackageDesignUploader), storage :file

      t.timestamps
    end
  end
end
