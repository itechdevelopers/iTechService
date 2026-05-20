module NotificationsHelper
  def notification_type_label(notification)
    Notification::TYPE_LABELS[notification.referenceable_type] ||
      notification.referenceable_type ||
      Notification::TYPE_LABELS[nil]
  end

  def notification_time_ago(time)
    "#{distance_of_time_in_words_to_now(time)} #{t(:ago)}"
  end

  def notification_chip_definitions(counts)
    total = counts.values.sum
    chips = [{ key: nil, label: 'Все', count: total }]

    Notification::TYPE_LABELS.each do |type, label|
      next if type.nil? && (counts[nil] || 0).zero?

      chips << {
        key: type.nil? ? 'null' : type,
        label: label,
        count: counts[type] || 0
      }
    end

    chips
  end

  def notification_chip_active?(chip_key, current_filter)
    chip_key.to_s == current_filter.to_s
  end
end
