class AddListenAllTranscriptionsAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.create!(name: 'listen_all_transcriptions')
  end

  def down
    Ability.find_by(name: 'listen_all_transcriptions')&.destroy
  end
end
