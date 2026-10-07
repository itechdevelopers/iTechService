# frozen_string_literal: true

module ClientChat
  # Диалог, который начинает сотрудник: находим клиента в MAX по номеру и
  # пишем первым. Только канал max_phone — боты по правилам своих платформ не
  # могут написать человеку, пока тот сам их не запустил.
  #
  # Сообщение человеку, который нам не писал, мессенджер считает похожим на
  # спам. Ограничение ляжет на весь аккаунт, а с ним и на переписку с
  # клиентами, поэтому новых диалогов за сутки не больше, чем задано в
  # настройках.
  class StartConversation
    CHANNEL = 'max_phone'
    DAILY_LIMIT_SETTING = :client_chat_max_phone_daily_starts
    DEFAULT_DAILY_LIMIT = 30

    Result = Struct.new(:status, :conversation, :search, keyword_init: true) do
      def success?
        %i[started existing].include?(status)
      end
    end

    def self.call(client:, user:, body:)
      new(client: client, user: user, body: body).call
    end

    # Пустая настройка — значение по умолчанию; 0 — начинать нельзя совсем.
    def self.daily_limit
      raw = Setting.get_value(DAILY_LIMIT_SETTING, nil).to_s.strip
      raw.match?(/\A\d+\z/) ? raw.to_i : DEFAULT_DAILY_LIMIT
    end

    # Скользящие сутки, а не календарные: у сотрудников разных городов
    # «сегодня» начинается в разное время, а лимит у аккаунта один.
    def self.started_last_day
      ClientConversation.where.not(started_by_id: nil).where('created_at >= ?', 24.hours.ago).count
    end

    def self.limit_reached?
      started_last_day >= daily_limit
    end

    def initialize(client:, user:, body:)
      @client = client
      @user = user
      @body = body.to_s.strip
    end

    def call
      return result(:empty_body) if @body.blank?

      # Открытый диалог с клиентом уже есть — пишем в него: второй диалог с тем
      # же человеком расщепил бы переписку, а лимит тратить незачем.
      existing = ClientConversation.opened.in_channel(CHANNEL).find_by(client_id: @client.id)
      return post_into(existing) if existing
      return result(:limit_reached) if self.class.limit_reached?

      search = MaxPhoneAccountSearch.call(@client.full_phone_number)
      return result(search.status, search: search) unless search.found?

      existing = ClientConversation.open_for(CHANNEL, search.chat_id)
      return post_into(existing, search) if existing

      start(search)
    end

    private

    def start(search)
      conversation = nil
      message = nil
      # Своя точка сохранения: если создание упадёт на уникальном индексе,
      # откатится только она, а не транзакция того, кто нас вызвал.
      ClientConversation.transaction(requires_new: true) do
        conversation = ClientConversation.create!(
          channel: CHANNEL, external_chat_id: search.chat_id, client: @client,
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
      existing = ClientConversation.open_for(CHANNEL, search.chat_id)
      raise if existing.nil?

      post_into(existing, search)
    end

    def post_into(conversation, search = nil)
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
