class AddSummaryToCallTranscriptions < ActiveRecord::Migration[5.1]
  def change
    add_column :call_transcriptions, :summary, :text
  end
end
