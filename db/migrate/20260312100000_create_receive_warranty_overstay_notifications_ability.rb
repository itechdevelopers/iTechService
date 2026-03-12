class CreateReceiveWarrantyOverstayNotificationsAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'receive_warranty_overstay_notifications')
  end

  def down
    Ability.find_by(name: 'receive_warranty_overstay_notifications')&.destroy
  end
end
