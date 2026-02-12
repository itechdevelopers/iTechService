class AddSentimentToCallTranscriptions < ActiveRecord::Migration[5.1]
  def up
    add_column :call_transcriptions, :sentiment, :string, array: true, default: []

    CallTranscription.find_each do |ct|
      sentiments = ct.transcript_text.to_s.scan(/\[.*?\s(positive|negative|neutral)\]/).flatten.uniq
      ct.update_column(:sentiment, sentiments) if sentiments.any?
    end
  end

  def down
    remove_column :call_transcriptions, :sentiment
  end
end
