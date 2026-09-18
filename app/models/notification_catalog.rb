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
    requests: 'Запросы клиентов',
    reviews: 'Отзывы',
    schedule: 'График'
  }.freeze

  Entry = Struct.new(
    :key, :group, :title, :hint, :audience,
    :channels, :default_channels, :default_color, :default_bold,
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
                 default_color: 'red', default_bold: false,
                 repeat_window_minutes: nil, mandatory: false,
                 visible_to: ->(_user) { true })
    Entry.new(
      key: key, group: group, title: title, hint: hint, audience: audience,
      channels: channels, default_channels: default_channels,
      default_color: default_color, default_bold: default_bold,
      repeat_window_minutes: repeat_window_minutes,
      mandatory: mandatory, visible_to: visible_to
    )
  end
  private_class_method :entry

  # Локация с кодом repair, repairmac и т. п.: аудитории согласований и
  # тестирования отбираются в запросах через LIKE 'repair%', повторяем тот же
  # критерий, чтобы настройка не разошлась с реальной рассылкой.
  SUPERADMIN = ->(user) { user.superadmin? }

  OVERSTAY_ABILITY = lambda do |user|
    user.able_to?('receive_warranty_overstay_notifications')
  end

  RECEIPT_REQUESTS = lambda do |user|
    user.superadmin? || user.able_to?('work_with_receipt_search_requests')
  end

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
          visible_to: SUPERADMIN),

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
          visible_to: SUPERADMIN),

    entry('location_overstay',
          group: :repair,
          title: 'Устройство залежалось на локации',
          hint: 'Работа стоит на одной локации дольше порога',
          audience: 'право receive_warranty_overstay_notifications',
          default_bold: true,
          visible_to: OVERSTAY_ABILITY),

    entry('warranty_overstay',
          group: :repair,
          title: 'Залежалось наше устройство',
          hint: 'Проданное нами устройство стоит дольше порога',
          audience: 'право receive_warranty_overstay_notifications',
          default_bold: true,
          visible_to: OVERSTAY_ABILITY),

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
          visible_to: REPAIR_LOCATION),

    entry('glass_sticking',
          group: :quality,
          title: 'Наклейка стекла',
          hint: 'Стекольщик сообщил, что устройство готово или что с ним проблема',
          audience: 'сотрудники локации «Бар» своего подразделения, кроме отправителя',
          default_color: 'blue',
          visible_to: ->(user) { user.location&.code == 'bar' }),

    entry('queue_inactivity',
          group: :quality,
          title: 'Клиент в очереди ждёт слишком долго',
          hint: 'Талон не берут в работу дольше порога',
          audience: 'суперадмины',
          visible_to: SUPERADMIN),

    entry('marker_words',
          group: :quality,
          title: 'Слова-маркеры в транскрипции звонка',
          hint: 'В расшифровке разговора встретились отслеживаемые слова',
          audience: 'суперадмины',
          visible_to: SUPERADMIN),

    entry('transcription_silence',
          group: :quality,
          title: 'Транскрипции звонков не приходят',
          hint: 'Новых расшифровок нет дольше заданного числа часов',
          audience: 'суперадмины',
          visible_to: SUPERADMIN),

    entry('find_my_device_down',
          group: :quality,
          title: 'Сервис проверки «Найти iPhone» не отвечает',
          hint: 'Проверка при приёмке не работает, её можно отключить',
          audience: 'суперадмины',
          visible_to: SUPERADMIN),

    entry('order_without_article',
          group: :orders,
          title: 'Заказ создан без артикула',
          hint: 'В заказе вашего подразделения не заполнен артикул',
          audience: 'право receive_merchandiser_notifications в подразделении заказа',
          visible_to: ->(user) { user.able_to?('receive_merchandiser_notifications') }),

    entry('one_c_sync_failure',
          group: :orders,
          title: 'Заказ не синхронизировался с 1С',
          hint: 'Все попытки синхронизации исчерпаны, нужно вмешаться руками',
          audience: 'право receive_merchandiser_notifications в подразделении заказа',
          visible_to: ->(user) { user.able_to?('receive_merchandiser_notifications') }),

    entry('one_c_order_result',
          group: :orders,
          title: 'Результат операции с заказом в 1С',
          hint: 'Итог синхронизации, обновления или удаления заказа, которое запустили вы',
          audience: 'тот, кто запустил операцию'),

    entry('kanban_card_deadline',
          group: :kanban,
          title: 'Дедлайн канбан-карточки',
          hint: 'Срок завтра, сегодня или уже просрочен',
          audience: 'ответственные по карточке',
          default_channels: CHANNELS),

    entry('kanban_card_created',
          group: :kanban,
          title: 'Новая карточка на доске',
          hint: 'На доске, где вы ответственный, появилась карточка',
          audience: 'ответственные на доске, кроме автора действия',
          default_channels: %i[telegram].freeze),

    entry('kanban_card_moved',
          group: :kanban,
          title: 'Карточку перенесли между колонками',
          hint: 'Движение по карточке, где вы автор или ответственный',
          audience: 'автор и ответственные по карточке, кроме автора действия',
          default_channels: %i[telegram].freeze),

    entry('kanban_card_done',
          group: :kanban,
          title: 'Карточку перенесли в «Готово»',
          hint: 'Работа по карточке завершена',
          audience: 'автор и ответственные по карточке, кроме автора действия',
          default_channels: %i[telegram].freeze),

    entry('kanban_card_comment',
          group: :kanban,
          title: 'Комментарий к канбан-карточке',
          audience: 'автор, ответственные по карточке и ответственные на доске',
          default_channels: CHANNELS),

    entry('merit_issued',
          group: :personal,
          title: 'Вам выставили плюс',
          audience: 'тот, кому выставили плюс',
          default_channels: CHANNELS),

    entry('fault_issued',
          group: :personal,
          title: 'Вам выставили минус',
          audience: 'тот, кому выставили минус',
          default_channels: CHANNELS),

    entry('achievement_granted',
          group: :personal,
          title: 'Получено достижение',
          audience: 'тот, кто получил достижение'),

    entry('telegram_media_attached',
          group: :personal,
          title: 'Фото или видео из Telegram прикреплено к работе',
          hint: 'Подтверждение, что присланный боту файл лёг в нужную работу',
          audience: 'тот, кто прислал файл боту',
          default_channels: %i[telegram].freeze),

    entry('package_low_stock',
          group: :warehouse,
          title: 'Заканчиваются пакеты',
          hint: 'Остаток по строке опустился до порога',
          audience: 'админы и суперадмины',
          default_channels: CHANNELS,
          visible_to: ->(user) { user.any_admin? }),

    entry('inventory_assigned',
          group: :warehouse,
          title: 'Ревизия: нужно посчитать',
          hint: 'Появилось задание на ревизию или часть позиций вернули на пересчёт',
          audience: 'сотрудники складских локаций подразделения и подписчики ревизии',
          default_channels: CHANNELS),

    entry('inventory_reviewed',
          group: :warehouse,
          title: 'Ревизия: результат',
          hint: 'Ревизия проведена или закрыта — с итогами расхождений',
          audience: 'автор ревизии, подписчики и суперадмины',
          default_channels: CHANNELS),

    entry('client_request_under_year',
          group: :requests,
          title: 'Запрос чека: покупке меньше года',
          audience: 'суперадмины и право work_with_receipt_search_requests',
          default_bold: true,
          visible_to: RECEIPT_REQUESTS),

    entry('client_request_one_to_two',
          group: :requests,
          title: 'Запрос чека: покупке от года до двух',
          audience: 'суперадмины и право work_with_receipt_search_requests',
          default_color: 'orange',
          default_bold: true,
          visible_to: RECEIPT_REQUESTS),

    entry('client_request_over_two',
          group: :requests,
          title: 'Запрос чека: покупке больше двух лет',
          audience: 'суперадмины и право work_with_receipt_search_requests',
          default_color: 'gray',
          default_bold: true,
          visible_to: RECEIPT_REQUESTS),

    entry('client_request_unconfirmed',
          group: :requests,
          title: 'Запрос чека: покупку подтвердить не удалось',
          hint: '1С недоступна или устройство продано не нами',
          audience: 'суперадмины и право work_with_receipt_search_requests',
          default_bold: true,
          visible_to: RECEIPT_REQUESTS),

    entry('device_unlock_created',
          group: :requests,
          title: 'Создан запрос на разблокировку',
          audience: 'суперадмины',
          visible_to: SUPERADMIN),

    entry('device_unlock_activity',
          group: :requests,
          title: 'Движение по запросу на разблокировку',
          hint: 'Сменился статус, появился комментарий или запрос завис без ответа',
          audience: 'подписчики запроса'),

    entry('gis_review_negative',
          group: :reviews,
          title: 'Новый негативный отзыв 2ГИС',
          audience: 'суперадмины',
          default_channels: CHANNELS,
          visible_to: SUPERADMIN),

    entry('gis_review_claim',
          group: :reviews,
          title: 'Заявка на закрепление отзыва',
          hint: 'Сотрудник просит закрепить отзыв за собой либо на отзыв претендуют двое',
          audience: 'суперадмины и право manage_negative_reviews',
          visible_to: ->(user) { user.superadmin? || user.able_to?('manage_negative_reviews') }),

    entry('gis_review_claim_resolved',
          group: :reviews,
          title: 'Решение по вашей заявке на отзыв',
          hint: 'Заявку на закрепление отзыва одобрили или отклонили',
          audience: 'автор заявки'),

    entry('review_source_alert',
          group: :reviews,
          title: 'Сбор отзывов не работает',
          hint: 'Площадка или филиал перестали отдавать отзывы',
          audience: 'суперадмины',
          default_channels: CHANNELS,
          visible_to: SUPERADMIN),

    entry('review_source_digest',
          group: :reviews,
          title: 'Дайджест аварий сбора отзывов',
          hint: 'Раз в сутки — все открытые аварии одним сообщением',
          audience: 'суперадмины',
          default_channels: %i[telegram].freeze,
          visible_to: SUPERADMIN),

    entry('schedule_conflict',
          group: :schedule,
          title: 'Конфликт в графике',
          hint: 'У уволенного или невышедшего сотрудника остались назначения',
          audience: 'суперадмины',
          visible_to: SUPERADMIN)
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
