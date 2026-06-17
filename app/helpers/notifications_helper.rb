module NotificationsHelper
  # CSS-классы корневого .single-notification + модификатор по kind.
  # Один источник правды для _short_/_full_notification (broadcast рендерит
  # short, модалка/поповер — full). kind → класс: подчёркивания в дефис
  # (client_request_under_year → single-notification--client-request-under-year).
  def single_notification_class(notification)
    kind = notification.kind
    modifier =
      if kind.blank?
        nil
      elsif kind.start_with?('warranty_overstay') || kind.start_with?('location_overstay')
        'single-notification--warranty-overstay'
      elsif kind.start_with?('client_request')
        "single-notification--#{kind.tr('_', '-')}"
      end

    ['single-notification', modifier].compact.join(' ')
  end

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
