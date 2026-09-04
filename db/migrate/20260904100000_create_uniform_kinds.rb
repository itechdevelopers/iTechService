class CreateUniformKinds < ActiveRecord::Migration[5.1]
  def change
    create_table :uniform_kinds do |t|
      t.string  :name, null: false
      t.text    :description
      t.decimal :cost, precision: 10, scale: 2 # себестоимость единицы, одна на все размеры
      t.string  :image # CarrierWave (UniformKindUploader), storage :file

      t.timestamps
    end
  end
end
