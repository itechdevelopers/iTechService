# frozen_string_literal: true

module ClientChat
  # Где человеку можно написать первым — по каждому каналу. Сотрудник видит,
  # в каких мессенджерах человек есть, и выбирает один.
  #
  # Каналы GREEN-API спрашивают мессенджер (с кэшем и паузой — см.
  # GreenApi::AccountSearch), и только пока лимит новых диалогов на сутки не
  # исчерпан: иначе проверка зря тратила бы обращения, за которые мессенджер
  # ограничивает аккаунт. Боты по номеру никого не находят, но в чат человека,
  # который им уже писал, написать могут — такой чат ищем в наших диалогах.
  class Reachability
    # Порядок строк и выбор по умолчанию, если человек нигде ещё не писал.
    PRIORITY = %w[whatsapp max_phone telegram max].freeze

    Option = Struct.new(:channel, :status, :conversation, :name, :checked_at, :retry_at, :last_activity_at,
                        keyword_init: true) do
      def available?
        %i[available open].include?(status)
      end
    end

    Result = Struct.new(:client, :phone, :options, keyword_init: true) do
      def available
        options.select(&:available?)
      end

      # Где человек был последним — там он скорее и ответит.
      def default_channel
        recent = available.select(&:last_activity_at).max_by(&:last_activity_at)
        (recent || available.first)&.channel
      end
    end

    def self.call(client: nil, phone: nil)
      new(client: client, phone: phone).call
    end

    def initialize(client:, phone:)
      @phone = Phone.normalize(phone.presence || client&.full_phone_number)
      @client = client || (@phone && Phone.find_client(@phone))
    end

    def call
      Result.new(client: @client, phone: @phone, options: channels.map { |channel| option_for(channel) }.compact)
    end

    private

    # Каналы GREEN-API — только подключённые. Боты — всегда, но строка
    # появится, только если человек им писал: иначе писать туда некуда.
    def channels
      PRIORITY.select do |channel|
        ClientConversation::BOT_CHANNELS.include?(channel) || GreenApi::Channel.fetch(channel).credentials.configured?
      end
    end

    def option_for(channel)
      chats = PersonChats.in(channel, client: @client, phone: @phone)
      open = PersonChats.latest(chats.opened)
      if open
        return Option.new(channel: channel, status: :open, conversation: open, name: open.contact_name,
                          last_activity_at: open.last_message_at)
      end

      latest = PersonChats.latest(chats)
      ClientConversation::BOT_CHANNELS.include?(channel) ? bot_option(channel, latest) : green_api_option(channel, latest)
    end

    def bot_option(channel, latest)
      return if latest.nil?

      Option.new(channel: channel, status: :available, conversation: latest, name: latest.contact_name,
                 last_activity_at: latest.last_message_at)
    end

    # Без номера искать нечего, и это важнее исчерпанного лимита: лимит
    # пройдёт сам, а номер надо вписать.
    def green_api_option(channel, latest)
      return Option.new(channel: channel, status: :invalid_phone) if @phone.nil?
      return Option.new(channel: channel, status: :limit_reached) if StartConversation.limit_reached?(channel)

      search = GreenApi::Channel.fetch(channel).account_search.call(@phone)
      Option.new(channel: channel, status: search.found? ? :available : search.status, name: search.name,
                 checked_at: search.checked_at, retry_at: search.retry_at, last_activity_at: latest&.last_message_at)
    end
  end
end
