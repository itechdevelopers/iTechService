# frozen_string_literal: true

# Диалог с клиентом в мессенджере. Бот — только транспорт: и авторство ответа,
# и тайминги существуют исключительно здесь, потому что Bot API про наших
# сотрудников ничего не знает.
class ClientConversation < ApplicationRecord
  CHANNELS = %w[telegram].freeze
  STATUSES = %w[open closed].freeze

  # Сутки тишины — и диалог считается завершённым (закрывает cron-джоб).
  # Следующее сообщение из того же чата заведёт новый диалог, поэтому
  # длительность остаётся осмысленной величиной, а не растёт бесконечно.
  STALE_AFTER = 24.hours

  # Дольше этого клиент ждёт ответа «слишком долго» — строка в списке краснеет.
  WAITING_ALERT = 15.minutes

  # Все четыре связи необязательны: клиент может остаться неопознанным, филиал —
  # неопределённым, ответственного может не быть, а пустой closed_by у закрытого
  # диалога означает автозакрытие по тишине.
  #
  # optional: true обязателен, несмотря на строку belongs_to_required_by_default
  # в new_framework_defaults.rb: она применяется уже после того, как
  # ActiveRecord прочитал эту настройку, и ни на что не влияет.
  belongs_to :client, optional: true
  belongs_to :department, optional: true
  belongs_to :assigned_user, class_name: 'User', optional: true
  belongs_to :closed_by, class_name: 'User', optional: true

  has_many :messages, -> { order(:created_at) },
           class_name: 'ClientMessage', dependent: :destroy, inverse_of: :conversation

  validates :channel, :external_chat_id, :status, presence: true
  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }

  # Статус — строковая колонка со scope'ами вместо enum: enum сгенерировал бы
  # класс-метод `open`, конфликтующий с Kernel#open.
  scope :opened, -> { where(status: 'open') }
  scope :closed, -> { where(status: 'closed') }
  # COALESCE, а не голый last_message_at: диалог заводится на /start, до первого
  # сообщения, и пустой всплыл бы в начало списка (в Postgres NULL идёт первым
  # при DESC) и никогда не попал бы в :stale (NULL <= X даёт NULL, не true).
  scope :recent, -> { order(Arel.sql('COALESCE(last_message_at, created_at) DESC')) }
  scope :in_channel, ->(channel) { where(channel: channel) }
  scope :assigned_to, ->(user) { where(assigned_user_id: user) }
  scope :stale, lambda {
    opened.where('COALESCE(last_message_at, created_at) <= ?', STALE_AFTER.ago)
  }

  # Ждут ответа: есть входящее новее последнего ответа сотрудника. Считаем
  # именно по last_reply_at, а не по last_message_at: автоответ вне рабочих
  # часов — тоже исходящее, и по last_message_at ночные диалоги к утру
  # «отвечены» роботом и выпали бы из этого фильтра.
  scope :awaiting_reply, lambda {
    opened.where('last_inbound_at IS NOT NULL')
          .where('last_reply_at IS NULL OR last_reply_at < last_inbound_at')
  }

  # Человекочитаемая длительность для списка: секунды → «12 мин», «3 ч 20 мин».
  # Формат на уровне модели — как DepartmentWorkingHours#time_range: значение
  # показывается в нескольких местах и должно выглядеть одинаково.
  def self.human_duration(seconds)
    return nil if seconds.blank?
    return "#{seconds} с" if seconds < 60

    minutes = seconds / 60
    return "#{minutes} мин" if minutes < 60

    hours = minutes / 60
    return "#{hours} ч #{minutes % 60} мин" if hours < 24

    "#{hours / 24} д #{hours % 24} ч"
  end

  # Диалоги ведёт локация Медиа. Location#is_media? — это code == 'content';
  # роль `media` у пользователя это другая сущность и сюда не относится.
  def self.notification_recipients
    User.active.staff.located_at(Location.content)
  end

  def self.open_for(channel, external_chat_id)
    opened.find_by(channel: channel, external_chat_id: external_chat_id)
  end

  def open?
    status == 'open'
  end

  def closed?
    status == 'closed'
  end

  def awaiting_reply?
    return false unless open? && last_inbound_at.present?

    last_reply_at.blank? || last_reply_at < last_inbound_at
  end

  # Сколько клиент ждёт ответа прямо сейчас.
  def waiting_seconds
    return nil unless awaiting_reply?

    (Time.current - last_inbound_at).to_i
  end

  # Время первого ответа — основная метрика качества.
  def first_reply_seconds
    return nil if first_reply_at.blank? || started_at.blank?

    (first_reply_at - started_at).to_i
  end

  # Длительность диалога. У открытого считается «на сейчас», поэтому растёт
  # при каждом вызове — зафиксируется в момент закрытия.
  def duration_seconds
    return nil if started_at.blank?

    ((closed_at || Time.current) - started_at).to_i
  end

  # Взятие в работу и перехват — одно действие: диалог переходит к тому, кто
  # нажал. Запрещать перехват нечего (отвечать всё равно может любой), но след
  # в ленте остаётся, чтобы прежний ответственный понял, куда делся диалог.
  def assign_to!(user)
    return false if assigned_user_id == user&.id

    previous = assigned_user
    transaction do
      update!(assigned_user: user)
      add_system_message(assignment_note(previous, user))
    end
    true
  end

  # user пуст ⇒ закрыл не человек, а суточная тишина.
  def close!(user = nil)
    transaction do
      update!(status: 'closed', closed_at: Time.current, closed_by: user)
      add_system_message(closing_note(user))
    end
  end

  # Колокольчик о новом сообщении. Зовём ТОЛЬКО когда диалог переходит в
  # состояние «ждёт ответа» (первое сообщение или сообщение после нашего
  # ответа): клиент, приславший пять реплик подряд, иначе выдал бы по пять
  # уведомлений каждому медийщику.
  #
  # Ответственный получает уведомление, даже если сидит не в Медиа, — иначе
  # взятый в работу диалог перестал бы до него доходить.
  def notify_new_message(message)
    recipients = (self.class.notification_recipients.to_a + [assigned_user]).compact.uniq
    return if recipients.empty?

    text = notification_text(message)
    url = Rails.application.routes.url_helpers.client_conversation_path(self)

    recipients.each do |recipient|
      notification = Notification.create!(user: recipient, message: text,
                                          url: url, referenceable: self)
      UserNotificationChannel.broadcast_to(recipient, notification)
    end
  end

  # Запись в ленте, которой клиент не увидит: отметки о взятии в работу и
  # закрытии. delivery_status 'sent' здесь значит «доставлять нечего».
  def add_system_message(text)
    messages.create!(direction: 'out', kind: 'system', body: text,
                     delivery_status: 'sent')
  end

  # Как показать собеседника: опознанный клиент, иначе то, что дал мессенджер.
  def contact_title
    client&.short_name.presence ||
      contact_name.presence ||
      (contact_username.present? ? "@#{contact_username}" : nil) ||
      contact_phone.presence ||
      "Чат #{external_chat_id}"
  end

  # Двигает таймлайн после добавления сообщения. started_at и first_reply_at
  # выставляются ровно один раз, поэтому пишутся только по nil.
  #
  # update_columns, а не update!: валидации тут нечего проверять, а лишний
  # save спровоцировал бы колбэки на каждое сообщение чата.
  def register_message(message)
    # Служебные записи таймлайн не двигают. Иначе взятие диалога в работу
    # обнуляло бы счётчик суточной тишины, и забытый диалог не закрылся бы
    # автоматически; автоответ бота делал бы то же с ночным обращением.
    return if message.system?

    attrs = { last_message_at: message.created_at, updated_at: Time.current }

    if message.inbound?
      attrs[:started_at] = message.created_at if started_at.blank?
      attrs[:last_inbound_at] = message.created_at
    elsif message.from_employee?
      attrs[:first_reply_at] = message.created_at if first_reply_at.blank?
      attrs[:last_reply_at] = message.created_at
    end

    update_columns(attrs)
  end

  private

  def notification_text(message)
    snippet = message.body.presence || '[фото]'
    "Сообщение от клиента (#{contact_title}): #{snippet.to_s.truncate(80)}"
  end

  def assignment_note(previous, current)
    if current.nil?
      "Диалог снят с сотрудника #{previous.short_name}"
    elsif previous.nil?
      "Диалог взят в работу: #{current.short_name}"
    else
      "Диалог перехвачен: #{current.short_name} (был за #{previous.short_name})"
    end
  end

  def closing_note(user)
    return "Диалог закрыт: #{user.short_name}" if user

    'Диалог закрыт автоматически — сутки без сообщений'
  end
end
