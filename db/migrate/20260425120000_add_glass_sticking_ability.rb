class AddGlassStickingAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'glass_sticking')
  end

  def down
    Ability.find_by(name: 'glass_sticking')&.destroy
  end
end
