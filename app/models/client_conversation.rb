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

  # Все четыре связи необязательны: клиент может остаться неопознанным, город —
  # неопределённым, ответственного может не быть, а пустой closed_by у закрытого
  # диалога означает автозакрытие по тишине.
  #
  # optional: true обязателен, несмотря на строку belongs_to_required_by_default
  # в new_framework_defaults.rb: она применяется уже после того, как
  # ActiveRecord прочитал эту настройку, и ни на что не влияет.
  belongs_to :client, optional: true
  belongs_to :city, optional: true
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

  # Сколько диалогов ждут ответа у этого сотрудника — число для иконки в
  # топбаре. Это состояние, а не журнал событий: ответил один — счётчик упал
  # у всех сам, закрывать ничего не нужно, и число всегда совпадает с тем,
  # что человек увидит на вкладке «Без ответа».
  #
  # Диалоги без города считаем всем: города у них нет ни у кого, и показать их
  # только «своим» невозможно — они просто потерялись бы.
  # Диалоги без города — всем: города у них нет ни у кого, и показать их
  # только «своим» невозможно, они просто потерялись бы. Сотрудник без города
  # (например, суперадмин вне подразделения) видит всё.
  def self.awaiting_for(user)
    return awaiting_reply if user&.city_id.blank?

    awaiting_reply.where(city_id: [user.city_id, nil])
  end

  def self.awaiting_count_for(user)
    awaiting_for(user).count
  end

  # Последнее НЕслужебное сообщение каждого диалога — одним запросом вместо
  # обращения к conversation.messages.last в каждой строке. Служебные записи
  # не годятся: нужно видеть, что сказал клиент, а не «диалог взят в работу».
  def self.last_messages_for(conversations)
    return {} if conversations.empty?

    ids = ClientMessage.where(client_conversation_id: conversations.map(&:id))
                       .where.not(kind: 'system')
                       .group(:client_conversation_id).maximum(:id)
    ClientMessage.where(id: ids.values).index_by(&:client_conversation_id)
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

  # Клиент проставляется сам, только когда он поделился контактом и телефон
  # нашёлся в базе. В остальных случаях Telegram номера не отдаёт, и связать
  # переписку с карточкой может лишь сотрудник — он видит, с кем говорит.
  def bind_client!(new_client)
    return false if client_id == new_client&.id

    previous = client
    transaction do
      update!(client: new_client)
      add_system_message(client_note(previous, new_client))
    end
    true
  end

  # Город определяется автоматически (ссылка, выбор клиента, опознание по
  # телефону), но ошибиться легко, а у диалога без города автоответ вне
  # рабочих часов не уходит вовсе — сотруднику нужен способ это поправить.
  def change_city!(new_city)
    return false if city_id == new_city&.id

    previous = city
    transaction do
      update!(city: new_city)
      add_system_message(city_note(previous, new_city))
    end
    # Диалог мог переехать в другой город — счётчики обоих изменились.
    ClientConversationCounterChannel.ping
    true
  end

  # user пуст ⇒ закрыл не человек, а суточная тишина.
  def close!(user = nil)
    transaction do
      update!(status: 'closed', closed_at: Time.current, closed_by: user)
      add_system_message(closing_note(user))
    end
    ClientConversationCounterChannel.ping
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

    # Первый ответивший забирает диалог себе. Кнопка «Взять в работу»
    # остаётся, но обычно сотрудник просто отвечает — и без этого правила
    # «Кто ведёт» пустовало бы у всех отвеченных диалогов.
    #
    # from_employee? отсекает автоответ бота: у него нет автора, и робот
    # ответственным стать не может.
    assign_to!(message.user) if message.from_employee? && assigned_user_id.nil?
  end

  private

  def assignment_note(previous, current)
    if current.nil?
      "Диалог снят с сотрудника #{previous.short_name}"
    elsif previous.nil?
      "Диалог взят в работу: #{current.short_name}"
    else
      "Диалог перехвачен: #{current.short_name} (был за #{previous.short_name})"
    end
  end

  def client_note(previous, current)
    return "Клиент отвязан (был #{previous.short_name})" if current.nil?
    return "Клиент привязан: #{current.short_name}" if previous.nil?

    "Клиент изменён: #{current.short_name} (был #{previous.short_name})"
  end

  def city_note(previous, current)
    return "Город убран (был #{previous.name})" if current.nil?
    return "Город указан: #{current.name}" if previous.nil?

    "Город изменён: #{current.name} (был #{previous.name})"
  end

  def closing_note(user)
    return "Диалог закрыт: #{user.short_name}" if user

    'Диалог закрыт автоматически — сутки без сообщений'
  end
end
