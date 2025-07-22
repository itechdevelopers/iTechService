class CreateReceiveMerchandiserNotificationsAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'receive_merchandiser_notifications')
  end

  def down
    Ability.find_by(name: 'receive_merchandiser_notifications')&.destroy
  end
end
