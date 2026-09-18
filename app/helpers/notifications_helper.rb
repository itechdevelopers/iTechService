module NotificationsHelper
  # CSS-классы корневого .single-notification: цвет и жирность берутся из
  # персональной настройки получателя. Один источник правды для
  # _short_/_full_notification (broadcast рендерит short, модалка и поповер —
  # full).
  #
  # preferences передают там, где рисуется список: без него каждая строка
  # сходила бы в базу за своей настройкой. Для одиночного broadcast'а его нет,
  # и настройка читается точечно.
  def single_notification_class(notification, preferences = nil)
    preference = preferences&.fetch(notification.type_key, nil) ||
                 UserNotificationPreference.for(notification.user, notification.type_key)

    classes = ['single-notification',
               "single-notification--color-#{preference&.color || 'red'}"]
    classes << 'single-notification--bold' if preference&.bold

    classes.join(' ')
  end

  # Цвет конвертика — самого приоритетного среди активных уведомлений: порядок
  # задан палитрой в NotificationCatalog::COLORS.
  def notifications_icon_color(type_keys, preferences)
    colors = type_keys.map { |key| preferences[key]&.color || 'red' }
    colors.min_by { |color| NotificationCatalog.color_priority(color) } || 'red'
  end

  # Слова-маркеры подсвечиваем только в уведомлениях о транскрипциях: в тексте
  # уведомления другого типа то же слово встречается случайно, и подсветка
  # обещала бы найденный маркер там, где его не искали.
  def notification_message_html(notification)
    return notification.message unless notification.referenceable_type == 'CallTranscription'

    sanitize(highlight_marker_words(notification.message))
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
