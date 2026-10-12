# frozen_string_literal: true

module ClientChat
  # Диалог, который начинает сотрудник: пишем человеку первым в выбранном
  # канале. Человек — карточка клиента или просто номер; карточку с этим
  # номером находим сами.
  #
  # Каналы GREEN-API (MAX и WhatsApp по номеру) ищут человека по номеру в
  # мессенджере. Боты незнакомцу написать не могут, но в чат человека, который
  # им уже писал, — могут: туда и пишем.
  #
  # Сообщение человеку, который нам не писал, мессенджер считает похожим на
  # спам. Ограничение ляжет на весь аккаунт, а с ним и на переписку с
  # клиентами, поэтому новых диалогов за сутки в каждом канале GREEN-API не
  # больше, чем задано в настройках. Ботам лимит не нужен: они пишут только
  # тем, кто им уже писал.
  class StartConversation
    # WhatsApp строже к сообщениям незнакомым людям, особенно с нового номера.
    DEFAULT_DAILY_LIMITS = { 'max_phone' => 30, 'whatsapp' => 10 }.freeze

    Result = Struct.new(:status, :conversation, :search, keyword_init: true) do
      def success?
        %i[started existing].include?(status)
      end
    end

    # name — как называть человека, если мессенджер имени не сообщит:
    # например, подпись номера в «Адресной книжке».
    def self.call(channel:, user:, body:, client: nil, phone: nil, name: nil)
      new(channel: channel, user: user, body: body, client: client, phone: phone, name: name).call
    end

    def self.limit_setting(channel)
      "client_chat_#{channel}_daily_starts"
    end

    # Пустая настройка — значение по умолчанию; 0 — начинать нельзя совсем.
    def self.daily_limit(channel)
      raw = Setting.get_value(limit_setting(channel), nil).to_s.strip
      raw.match?(/\A\d+\z/) ? raw.to_i : DEFAULT_DAILY_LIMITS.fetch(channel)
    end

    # Скользящие сутки, а не календарные: у сотрудников разных городов
    # «сегодня» начинается в разное время, а лимит у аккаунта один.
    def self.started_last_day(channel)
      ClientConversation.in_channel(channel).where.not(started_by_id: nil).where('created_at >= ?', 24.hours.ago).count
    end

    def self.limit_reached?(channel)
      started_last_day(channel) >= daily_limit(channel)
    end

    def initialize(channel:, user:, body:, client: nil, phone: nil, name: nil)
      @channel = channel.to_s
      raise ArgumentError, "нельзя начать диалог в канале #{channel.inspect}" unless ClientConversation::CHANNELS.include?(@channel)

      @phone = Phone.normalize(phone.presence || client&.full_phone_number)
      @client = client || (@phone && Phone.find_client(@phone))
      @name = name
      @user = user
      @body = body.to_s.strip
    end

    def call
      return result(:empty_body) if @body.blank?

      # Открытый диалог с человеком уже есть — пишем в него: второй диалог с тем
      # же человеком расщепил бы переписку, а лимит тратить незачем.
      existing = PersonChats.latest(PersonChats.in(@channel, client: @client, phone: @phone).opened)
      return post_into(existing) if existing

      ClientConversation::BOT_CHANNELS.include?(@channel) ? start_in_bot : start_in_green_api
    end

    private

    def start_in_green_api
      return result(:limit_reached) if self.class.limit_reached?(@channel)

      search = GreenApi::Channel.fetch(@channel).account_search.call(@phone)
      return result(search.status, search: search) unless search.found?

      existing = ClientConversation.open_for(@channel, search.chat_id)
      return post_into(existing, search) if existing

      start(chat_id: search.chat_id, phone: search.phone, name: search.name, search: search)
    end

    # Чат, куда человек уже писал боту. Новый диалог в нём продолжает ту же
    # переписку — прежние диалоги покажет история чата (ClientChat::History).
    def start_in_bot
      known = PersonChats.latest(PersonChats.in(@channel, client: @client, phone: @phone))
      return result(:not_found) if known.nil?

      existing = ClientConversation.open_for(@channel, known.external_chat_id)
      return post_into(existing) if existing

      start(chat_id: known.external_chat_id, phone: known.contact_phone || @phone,
            name: known.contact_name, city: known.city)
    end

    # Город — по последнему ремонту клиента; у бота без карточки — тот, что был
    # у прежнего диалога (его задаёт ссылка филиала, по которой человек пришёл).
    def start(chat_id:, phone:, name:, city: nil, search: nil)
      conversation = nil
      message = nil
      # Своя точка сохранения: если создание упадёт на уникальном индексе,
      # откатится только она, а не транзакция того, кто нас вызвал.
      ClientConversation.transaction(requires_new: true) do
        conversation = ClientConversation.create!(
          channel: @channel, external_chat_id: chat_id, client: @client,
          contact_phone: phone, contact_name: name.presence || @name.presence || @client&.short_name,
          city: (@client && ClientConversation.last_repair_city(@client)) || city,
          started_by: @user, assigned_user: @user
        )
        conversation.add_system_message("Диалог начат: #{@user.short_name}")
        message = outgoing(conversation)
      end
      deliver(message)
      result(:started, conversation: conversation, search: search)
    rescue ActiveRecord::RecordNotUnique
      # Человек написал, пока сотрудник набирал сообщение: открытый диалог этого
      # чата появился между проверкой и созданием.
      existing = ClientConversation.open_for(@channel, chat_id)
      raise if existing.nil?

      post_into(existing, search)
    end

    # Диалог с этим чатом мог идти без карточки клиента: человек писал первым,
    # и опознать его не вышло. Сотрудник пишет клиенту из базы — значит, знает,
    # кто это, и без привязки диалог так и не появился бы в карточке клиента.
    def post_into(conversation, search = nil)
      if conversation.client_id.nil? && @client
        conversation.bind_client!(@client)
        conversation.update!(city: ClientConversation.last_repair_city(@client)) if conversation.city.nil?
      end
      deliver(outgoing(conversation))
      result(:existing, conversation: conversation, search: search)
    end

    def outgoing(conversation)
      conversation.messages.create!(direction: 'out', kind: 'text', body: @body,
                                    user: @user, delivery_status: 'pending')
    end

    # После коммита, а не внутри транзакции: иначе Sidekiq мог бы взять
    # джобу раньше, чем строка станет видна, и молча её пропустить.
    def deliver(message)
      SendClientMessageJob.perform_later(message.id)
    end

    def result(status, **attrs)
      Result.new(status: status, **attrs)
    end
  end
end
