module CallTranscriptionsHelper
  SENTIMENT_COLORS = { 'positive' => '#4CAF50', 'negative' => '#F44336', 'neutral' => '#FFC107' }.freeze
  SENTIMENT_EMOJI = { 'positive' => "\u{1F7E2}", 'negative' => "\u{1F534}", 'neutral' => "\u{1F7E1}" }.freeze

  def sentiment_dots(transcription)
    return '-' if transcription.sentiment.blank?

    safe_join(transcription.sentiment.map { |s| sentiment_dot(s) }, ' ')
  end

  def format_transcript_with_sentiment(text)
    return '' if text.blank?

    with_emoji = text.gsub(/(positive|negative|neutral)/) do
      sentiment = $1
      "#{sentiment} #{SENTIMENT_EMOJI[sentiment]} "
    end
    simple_format(with_emoji)
  end

  private

  def sentiment_dot(sentiment)
    color = SENTIMENT_COLORS[sentiment]
    content_tag(:span, '', style: "background-color: #{color}; width: 10px; height: 10px; border-radius: 50%; display: inline-block; vertical-align: middle;", title: sentiment)
  end
end
