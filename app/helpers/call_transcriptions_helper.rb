module CallTranscriptionsHelper
  SENTIMENT_COLORS = { 'positive' => '#4CAF50', 'negative' => '#F44336', 'neutral' => '#FFC107' }.freeze

  def sentiment_dots(transcription)
    return '-' if transcription.sentiment.blank?

    safe_join(transcription.sentiment.map { |s|
      content_tag(:span, '', class: 'sentiment-dot',
        style: "background-color: #{SENTIMENT_COLORS[s]}; width: 12px; height: 12px; border-radius: 50%; display: inline-block;",
        title: s)
    }, ' ')
  end
end
