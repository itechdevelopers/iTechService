class CreateElqueueSounds < ActiveRecord::Migration[5.1]
  def change
    create_table :elqueue_sounds do |t|
      t.string :kind,  null: false # ElqueueSound::KINDS
      t.string :value, null: false # буквы талона, число или номер окна
      t.string :audio, null: false # ElqueueSoundUploader

      t.timestamps
    end

    add_index :elqueue_sounds, %i[kind value], unique: true
  end
end
