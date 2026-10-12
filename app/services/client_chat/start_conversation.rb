# frozen_string_literal: true

module ClientChat
  # Диалог, который начинает сотрудник: находим клиента в мессенджере по
  # номеру и пишем первым. Только каналы GREEN-API (MAX и WhatsApp по номеру) —
  # боты по правилам своих платформ не могут написать человеку, пока тот сам
  # их не запустил.
  #
  # Сообщение человеку, который нам не писал, мессенджер считает похожим на
  # спам. Ограничение ляжет на весь аккаунт, а с ним и на переписку с
  # клиентами, поэтому новых диалогов за сутки в каждом канале не больше, чем
  # задано в настройках.
  class StartConversation
    # WhatsApp строже к сообщениям незнакомым людям, особенно с нового номера.
    DEFAULT_DAILY_LIMITS = { 'max_phone' => 30, 'whatsapp' => 10 }.freeze

    Result = Struct.new(:status, :conversation, :search, keyword_init: true) do
      def success?
        %i[started existing].include?(status)
      end
    end

    def self.call(channel:, client:, user:, body:)
      new(channel: channel, client: client, user: user, body: body).call
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

    def initialize(channel:, client:, user:, body:)
      @channel = GreenApi::Channel.fetch(channel)
      @client = client
      @user = user
      @body = body.to_s.strip
    end

    def call
      return result(:empty_body) if @body.blank?

      # Открытый диалог с клиентом уже есть — пишем в него: второй диалог с тем
      # же человеком расщепил бы переписку, а лимит тратить незачем.
      existing = ClientConversation.opened.in_channel(channel).find_by(client_id: @client.id)
      return post_into(existing) if existing
      return result(:limit_reached) if self.class.limit_reached?(channel)

      search = @channel.account_search.call(@client.full_phone_number)
      return result(search.status, search: search) unless search.found?

      existing = ClientConversation.open_for(channel, search.chat_id)
      return post_into(existing, search) if existing

      start(search)
    end

    private

    def channel
      @channel.key
    end

    def start(search)
      conversation = nil
      message = nil
      # Своя точка сохранения: если создание упадёт на уникальном индексе,
      # откатится только она, а не транзакция того, кто нас вызвал.
      ClientConversation.transaction(requires_new: true) do
        conversation = ClientConversation.create!(
          channel: channel, external_chat_id: search.chat_id, client: @client,
          contact_phone: search.phone, contact_name: search.name.presence || @client.short_name,
          city: ClientConversation.last_repair_city(@client),
          started_by: @user, assigned_user: @user
        )
        conversation.add_system_message("Диалог начат: #{@user.short_name}")
        message = outgoing(conversation)
      end
      deliver(message)
      result(:started, conversation: conversation, search: search)
    rescue ActiveRecord::RecordNotUnique
      # Клиент написал, пока сотрудник набирал сообщение: открытый диалог этого
      # чата появился между проверкой и созданием.
      existing = ClientConversation.open_for(channel, search.chat_id)
      raise if existing.nil?

      post_into(existing, search)
    end

    # Диалог с этим чатом мог идти без карточки клиента: человек писал первым,
    # и опознать его не вышло. Сотрудник пишет из карточки — значит, знает, кто
    # это, и без привязки диалог так и не появился бы в карточке клиента.
    def post_into(conversation, search = nil)
      if conversation.client_id.nil?
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
