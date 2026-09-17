# frozen_string_literal: true

# Реестр уведомлений: перечень того, что сотрудник может настроить под себя —
# канал доставки, цвет, жирность, повторы.
#
# Ключ записи попадает в notifications.type_key и служит единственным
# идентификатором типа. Колонка kind для этого не годится: у неё есть вторая
# роль — ключ дедупликации, в который зашиты параметры повода
# (location_overstay_7_loc_42), так что на один тип там приходится столько
# значений, сколько порогов и локаций.
#
# visible_to сужаем ТОЛЬКО там, где аудитория задана явным фильтром по самому
# пользователю: роль, ability, локация. Если получателя определяет его роль в
# конкретной записи — автор задачи, мастер ремонта, адресат минуса, — предикат
# остаётся true. Сузив его по догадке, мы спрячем настройку у того, кто
# уведомление всё равно получит, и он не сможет от него отписаться.
#
# Кто что получает сегодня и откуда это взято — docs/notifications-audience-map.md.
module NotificationCatalog
  # Порядок значим: цвет конвертика в топбаре берётся у самого раннего в этом
  # списке цвета среди активных уведомлений.
  COLORS = %w[red orange yellow green blue purple gray].freeze

  CHANNELS = %i[in_app telegram].freeze

  IN_APP_ONLY = %i[in_app].freeze

  # Порядок задаёт последовательность разделов во вкладке настроек.
  GROUPS = {
    repair: 'Ремонт и приёмка',
    quality: 'Стекло, очередь, качество',
    orders: 'Заказы и 1С',
    kanban: 'Канбан',
    personal: 'Личные события',
    warehouse: 'Склад и ревизия',
    reviews: 'Отзывы',
    schedule: 'График'
  }.freeze

  Entry = Struct.new(
    :key, :group, :title, :hint, :audience,
    :channels, :default_channels, :default_color,
    :repeat_window_minutes, :mandatory, :visible_to,
    keyword_init: true
  ) do
    # Канал, который тип в принципе умеет: у части уведомлений второй канал
    # появится только вместе с текстом сообщения для него.
    def supports?(channel)
      channels.include?(channel)
    end

    def default_channel?(channel)
      default_channels.include?(channel)
    end

    def visible_to?(user)
      user.present? && visible_to.call(user)
    end

    def group_title
      GROUPS[group]
    end
  end

  # Дефолты подобраны так, чтобы поведение до первой настройки не отличалось от
  # нынешнего: канал тот же, цвет красный, повторов нет.
  def self.entry(key, group:, title:, audience:, hint: nil,
                 channels: CHANNELS, default_channels: IN_APP_ONLY,
                 default_color: 'red', repeat_window_minutes: nil,
                 mandatory: false, visible_to: ->(_user) { true })
    Entry.new(
      key: key, group: group, title: title, hint: hint, audience: audience,
      channels: channels, default_channels: default_channels,
      default_color: default_color, repeat_window_minutes: repeat_window_minutes,
      mandatory: mandatory, visible_to: visible_to
    )
  end
  private_class_method :entry

  # Локация с кодом repair, repairmac и т. п.: аудитории согласований и
  # тестирования отбираются в запросах через LIKE 'repair%', повторяем тот же
  # критерий, чтобы настройка не разошлась с реальной рассылкой.
  REPAIR_LOCATION = lambda do |user|
    user.location&.code.to_s.start_with?('repair')
  end

  ENTRIES = [
    entry('service_job_location_added',
          group: :repair,
          title: 'Новая работа на локации',
          hint: 'Устройство добавлено на локацию, к которой вы прикреплены',
          audience: 'сотрудники локации (кроме API-пользователей)',
          visible_to: ->(user) { !user.api? && user.location_id.present? }),

    entry('reception_photo_reminder',
          group: :repair,
          title: 'Напоминание: нет фото при приёмке',
          hint: 'Через полчаса после приёмки раздел «Фото при приёмке» всё ещё пуст',
          audience: 'ответственный за фото — автор задачи, из-за которой фото обязательно',
          default_channels: CHANNELS,
          repeat_window_minutes: 30),

    entry('reception_photo_fault',
          group: :repair,
          title: 'Минус за отсутствие фото при приёмке',
          hint: 'Через час фото так и не появилось, выставлен минус',
          audience: 'тот же ответственный за фото',
          default_channels: CHANNELS),

    entry('reception_photo_missing',
          group: :repair,
          title: 'Надзор: фото при приёмке не добавлено',
          hint: 'Сводка для контроля — с пометкой, выставлен ли минус',
          audience: 'суперадмины',
          visible_to: ->(user) { user.superadmin? }),

    entry('repair_attention',
          group: :repair,
          title: 'Маячок «айс»: вы смотрели эту задачу',
          hint: 'Вы открывали работу, но не взяли её в ремонт',
          audience: 'тот, кто открывал работу'),

    entry('repair_gluing',
          group: :repair,
          title: 'Устройство на проклейке',
          hint: 'Заданное число часов на проклейке истекло — пора забирать',
          audience: 'тот, кто поставил статус проклейки'),

    entry('repair_master_day_off',
          group: :repair,
          title: 'Мастер в выходном, ремонт не закрыт',
          hint: 'Работа осталась «в процессе ремонта», а мастер сегодня не работает',
          audience: 'смена на локации «Ремонт» того же подразделения',
          default_channels: CHANNELS,
          visible_to: REPAIR_LOCATION),

    entry('repair_status_flip',
          group: :repair,
          title: 'Качели статуса ремонта',
          hint: 'Статус сменили туда-обратно в обход «Строгого ремонта»',
          audience: 'суперадмины',
          visible_to: ->(user) { user.superadmin? }),

    entry('location_overstay',
          group: :repair,
          title: 'Устройство залежалось на локации',
          hint: 'Работа стоит на одной локации дольше порога',
          audience: 'право receive_warranty_overstay_notifications',
          visible_to: ->(user) { user.able_to?('receive_warranty_overstay_notifications') }),

    entry('warranty_overstay',
          group: :repair,
          title: 'Залежалось наше устройство',
          hint: 'Проданное нами устройство стоит дольше порога',
          audience: 'право receive_warranty_overstay_notifications',
          visible_to: ->(user) { user.able_to?('receive_warranty_overstay_notifications') }),

    entry('approval_requested',
          group: :repair,
          title: 'Запрошено согласование',
          hint: 'Технарь отправил вопрос на согласование',
          audience: 'смена медиа-локации подразделения',
          visible_to: ->(user) { user.location&.code == 'content' }),

    entry('approval_answered',
          group: :repair,
          title: 'Ответ по согласованию',
          hint: 'На согласование ответили — можно продолжать ремонт',
          audience: 'смена ремонтных локаций подразделения',
          visible_to: REPAIR_LOCATION),

    entry('testing_to_test',
          group: :repair,
          title: 'Устройство приехало на тестирование',
          hint: 'Работа отправлена на тест или на повторный тест',
          audience: 'смена целевой тест-локации',
          visible_to: ->(user) { user.location&.for_testing? }),

    entry('testing_returned',
          group: :repair,
          title: 'Устройство вернулось с тестирования',
          hint: 'Тест пройден или устройство возвращено технарю',
          audience: 'смена ремонтных локаций подразделения',
          visible_to: REPAIR_LOCATION)
  ].each_with_object({}) { |item, result| result[item.key] = item }.freeze

  def self.all
    ENTRIES.values
  end

  def self.keys
    ENTRIES.keys
  end

  def self.[](key)
    ENTRIES[key.to_s]
  end

  def self.key?(key)
    ENTRIES.key?(key.to_s)
  end

  # Пользователь интеграции получателем не бывает: у него нет ни колокольчика,
  # ни привязанного Telegram, а профиль с вкладкой настроек ему не открывают.
  def self.for_user(user)
    return [] if user.blank? || user.api?

    all.select { |item| item.visible_to?(user) }
  end

  # Разделы в порядке GROUPS; пустые не возвращаются, чтобы вкладка не рисовала
  # заголовок без единой строки под ним.
  def self.grouped_for_user(user)
    visible = for_user(user).group_by(&:group)

    GROUPS.keys.each_with_object({}) do |group, result|
      items = visible[group]
      result[group] = items if items.present?
    end
  end

  # Чем меньше число, тем выше приоритет цвета. Неизвестный цвет уходит в конец:
  # настройка могла остаться от палитры, которой больше нет.
  def self.color_priority(color)
    COLORS.index(color.to_s) || COLORS.size
  end
end
