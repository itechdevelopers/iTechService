# frozen_string_literal: true

require 'httparty'

module GreenApi
  # Поиск человека в мессенджере по номеру телефона — чтобы написать ему
  # первым. Наследники задают канал (CHANNEL) и сам запрос к мессенджеру
  # (check_account).
  #
  # Мессенджеры следят за проверками номеров: за частые и особенно за
  # повторные проверки номера без аккаунта они ограничивают весь аккаунт, а с
  # ним и переписку с клиентами. Поэтому к мессенджеру идём в последнюю
  # очередь: сначала ищем чат в диалогах, где человек уже писал, потом в
  # запомненных ответах. Если мессенджер всё же ответил, что лимит исчерпан,
  # проверки этого канала замирают на два часа для всех — флаг лежит в
  # Setting, потому что Rails.cache на проде у каждого процесса свой и паузу
  # бы не разделил.
  class AccountSearch
    Result = Struct.new(:status, :phone, :chat_id, :name, :checked_at, :retry_at, keyword_init: true) do
      def found?
        status == :found
      end
    end

    PAUSE = 2.hours
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    def self.call(phone)
      new(phone).call
    end

    def self.pause_setting
      "#{self::CHANNEL}_lookup_paused_until"
    end

    def self.paused_until
      value = Setting.find_by(name: pause_setting, department_id: nil)&.value
      time = value.present? ? Time.zone.parse(value) : nil
      time if time && time > Time.current
    rescue ArgumentError
      nil
    end

    def initialize(phone)
      @phone = ClientChat::Phone.normalize(phone).to_s
    end

    def call
      return result(:invalid_phone) if @phone.empty?

      known = known_from_conversation
      return known if known

      lookup = GreenApiLookup.find_by(channel: channel, phone: @phone)
      return from_lookup(lookup) if lookup&.fresh?

      paused = self.class.paused_until
      return result(:paused, retry_at: paused) if paused

      @credentials = Channel.fetch(channel).credentials
      return result(:not_configured) unless @credentials.configured?

      begin
        check_account
      rescue StandardError => e
        failure("#{e.class}: #{e.message}")
      end
    end

    private

    def channel
      self.class::CHANNEL
    end

    # Человек уже писал на этот номер — чат известен без единого запроса.
    def known_from_conversation
      conversation = ClientConversation.in_channel(channel).where(contact_phone: @phone)
                                       .order(created_at: :desc).first
      return if conversation.nil?

      result(:found, chat_id: conversation.external_chat_id, name: conversation.contact_name)
    end

    # 469 — лимит проверок исчерпан. Отказ 400 с «limit exceeded» в тексте —
    # тот же лимит, только по частоте.
    def limited?(response)
      return true if response.code == 469

      response.code == 400 && body(response).values_at('message', 'description').join(' ').match?(/limit exceeded/i)
    end

    def pause!
      until_time = PAUSE.from_now
      setting = Setting.find_or_initialize_by(name: self.class.pause_setting, department_id: nil)
      setting.value = until_time.iso8601
      setting.value_type = 'string'
      setting.presentation = I18n.t("settings.#{self.class.pause_setting}")
      setting.save!
      Rails.logger.warn("[#{self.class.name}] мессенджер ограничил проверку номеров, пауза до #{until_time}")
      result(:paused, retry_at: until_time)
    end

    def remember(found:, chat_id: nil, name: nil)
      lookup = GreenApiLookup.find_or_initialize_by(channel: channel, phone: @phone)
      lookup.update!(found: found, chat_id: chat_id, name: name, checked_at: Time.current)
      from_lookup(lookup)
    end

    def from_lookup(lookup)
      result(lookup.found? ? :found : :not_found,
             chat_id: lookup.chat_id, name: lookup.name, checked_at: lookup.checked_at)
    end

    # Сбой сети или неожиданный ответ ничего не говорит о номере — не
    # запоминаем его и паузу не ставим.
    def failure(detail)
      Rails.logger.error("[#{self.class.name}] #{@phone}: #{detail}")
      result(:error)
    end

    def result(status, **attrs)
      Result.new(status: status, phone: @phone, **attrs)
    end

    def post(name, payload)
      HTTParty.post(@credentials.method_url(name), body: payload.to_json,
                                                   headers: { 'Content-Type' => 'application/json' },
                                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
    end

    def body(response)
      response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    end
  end
end
