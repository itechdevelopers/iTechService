class AddManageSchedulesAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'manage_schedules')
  end

  def down
    Ability.find_by(name: 'manage_schedules')&.destroy
  end
end
