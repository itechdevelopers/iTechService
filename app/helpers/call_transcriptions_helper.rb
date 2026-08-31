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
    # Разметка вставляется до simple_format: его sanitize оставит наш span
    # (span и class — в allowlist) и вычистит любые теги из самого текста.
    simple_format(highlight_marker_words(with_emoji))
  end

  # Возвращает НЕ html_safe строку: экранирование делает вызывающая сторона
  # (simple_format на странице транскрипции, sanitize в уведомлениях).
  def highlight_marker_words(text)
    pattern = marker_words_pattern
    return text if text.blank? || pattern.nil?

    text.gsub(pattern) { |match| "<span class=\"marker-word-highlight\">#{match}</span>" }
  end

  def sentiment_dot(sentiment)
    color = SENTIMENT_COLORS[sentiment]
    content_tag(:span, '', style: "background-color: #{color}; width: 10px; height: 10px; border-radius: 50%; display: inline-block; vertical-align: middle;", title: sentiment)
  end

  private

  # Мемоизация на весь рендер: партиал уведомления рисуется коллекцией,
  # без неё был бы запрос к marker_words на каждое уведомление в поповере.
  def marker_words_pattern
    return @marker_words_pattern if defined?(@marker_words_pattern)

    # Длинные слова первыми: в альтернации побеждает левое совпадение, иначе
    # маркер «суд» подсветил бы лишь кусок маркера «судебный иск».
    words = MarkerWord.pluck(:word).reject(&:blank?).sort_by { |w| -w.length }
    @marker_words_pattern =
      words.any? ? Regexp.new(words.map { |w| Regexp.escape(w) }.join('|'), Regexp::IGNORECASE) : nil
  end
end
