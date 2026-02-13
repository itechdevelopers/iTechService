class AddCalledNumberToCallTranscriptions < ActiveRecord::Migration[5.1]
  def change
    add_column :call_transcriptions, :called_number, :string
  end
end
