class AddOverstayThresholdsToLocations < ActiveRecord::Migration[5.1]
  def change
    add_column :locations, :overstay_thresholds, :string
  end
end
