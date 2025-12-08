class CreateCallTranscriptions < ActiveRecord::Migration[5.1]
  def change
    create_table :call_transcriptions do |t|
      t.string :call_unique_id, null: false
      t.text :transcript_text, null: false
      t.string :caller_number, null: false
      t.datetime :call_date, null: false
      t.string :recording_url
      t.references :client, foreign_key: true, index: true

      t.timestamps
    end

    add_index :call_transcriptions, :call_unique_id, unique: true
    add_index :call_transcriptions, :caller_number
    add_index :call_transcriptions, :call_date
  end
end
