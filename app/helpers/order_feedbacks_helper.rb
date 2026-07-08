module OrderFeedbacksHelper
  # «осталось N дней» / «сегодня» / «просрочено на N дней» до желаемой даты,
  # с цветовой подсветкой срочности.
  def desired_date_countdown(desired_date)
    return if desired_date.blank?

    days = (desired_date - Date.current).to_i

    if days > 0
      text = "осталось #{days} #{days_word(days)}"
      modifier = days <= 2 ? 'soon' : 'ok'
    elsif days.zero?
      text = 'сегодня'
      modifier = 'soon'
    else
      text = "просрочено на #{days.abs} #{days_word(days)}"
      modifier = 'overdue'
    end

    content_tag :span, text, class: "order-feedback-countdown order-feedback-countdown--#{modifier}"
  end

  def days_word(number)
    remainder100 = number.abs % 100
    return 'дней' if (11..14).cover?(remainder100)

    case number.abs % 10
    when 1 then 'день'
    when 2, 3, 4 then 'дня'
    else 'дней'
    end
  end
end
