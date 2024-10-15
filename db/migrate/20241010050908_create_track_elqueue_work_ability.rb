class CreateTrackElqueueWorkAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'track_elqueue_work')
  end

  def down
    Ability.find_by(name: 'track_elqueue_work')&.destroy
  end
end
