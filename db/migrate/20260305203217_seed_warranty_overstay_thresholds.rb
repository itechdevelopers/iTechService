class SeedWarrantyOverstayThresholds < ActiveRecord::Migration[5.1]
  def up
    Setting.find_or_create_by!(name: 'warranty_overstay_thresholds', department_id: nil) do |s|
      s.value = '[30, 40]'
      s.value_type = 'json'
    end
  end

  def down
    Setting.find_by(name: 'warranty_overstay_thresholds', department_id: nil)&.destroy
  end
end
