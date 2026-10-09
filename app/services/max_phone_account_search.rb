# frozen_string_literal: true

require 'httparty'

# Поиск человека в MAX по номеру телефона — чтобы написать ему первым.
#
# MAX следит за проверками номеров: за частые и особенно за повторные проверки
# номера без аккаунта он временно ограничивает весь аккаунт, а с ним и
# переписку с клиентами. Поэтому в MAX идём в последнюю очередь: сначала ищем
# chat_id в диалогах, где человек уже писал, потом в запомненных ответах.
# Если MAX всё же ответил, что лимит исчерпан, проверки замирают на два часа
# для всех — флаг лежит в Setting, потому что Rails.cache на проде у каждого
# процесса свой и паузу бы не разделил.
class MaxPhoneAccountSearch
  Result = Struct.new(:status, :phone, :chat_id, :name, :checked_at, :retry_at, keyword_init: true) do
    def found?
      status == :found
    end
  end

  PAUSE = 2.hours
  PAUSE_SETTING = 'max_phone_lookup_paused_until'
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  def self.call(phone)
    new(phone).call
  end

  def self.paused_until
    value = Setting.find_by(name: PAUSE_SETTING, department_id: nil)&.value
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

    lookup = MaxPhoneLookup.find_by(phone: @phone)
    return from_lookup(lookup) if lookup&.fresh?

    paused = self.class.paused_until
    return result(:paused, retry_at: paused) if paused

    @credentials = GreenApi::Channel.fetch('max_phone').credentials
    return result(:not_configured) unless @credentials.configured?

    check_account
  end

  private

  # Человек уже писал на этот номер — chat_id известен без единого запроса.
  def known_from_conversation
    conversation = ClientConversation.in_channel('max_phone').where(contact_phone: @phone)
                                     .order(created_at: :desc).first
    return if conversation.nil?

    result(:found, chat_id: conversation.external_chat_id, name: conversation.contact_name)
  end

  def check_account
    response = post('checkAccount', phoneNumber: @phone.to_i)
    return pause! if limited?(response)
    return failure("checkAccount: HTTP #{response.code}") unless response.code == 200 && body(response).key?('exist')

    chat_id = body(response)['chatId'].to_s
    if body(response)['exist'] == true && chat_id.present?
      remember(found: true, chat_id: chat_id, max_name: profile_name(chat_id))
    else
      remember(found: false)
    end
  rescue StandardError => e
    failure("#{e.class}: #{e.message}")
  end

  # Имя из профиля MAX: по нему сотрудник видит, кому пишет, — номер в базе
  # мог давно перейти к другому человеку. Без имени поиск всё равно удался.
  def profile_name(chat_id)
    response = post('getContactInfo', chatId: chat_id)
    pause! if limited?(response)
    response.code == 200 ? body(response)['name'].to_s.strip.presence : nil
  rescue StandardError => e
    Rails.logger.warn("[MaxPhoneAccountSearch] getContactInfo: #{e.class}: #{e.message}")
    nil
  end

  # 469 — лимит проверок исчерпан. Отказ 400 с «limit exceeded» в тексте —
  # тот же лимит, только по частоте.
  def limited?(response)
    return true if response.code == 469

    response.code == 400 && body(response).values_at('message', 'description').join(' ').match?(/limit exceeded/i)
  end

  def pause!
    until_time = PAUSE.from_now
    setting = Setting.find_or_initialize_by(name: PAUSE_SETTING, department_id: nil)
    setting.value = until_time.iso8601
    setting.value_type = 'string'
    setting.presentation = I18n.t("settings.#{PAUSE_SETTING}")
    setting.save!
    Rails.logger.warn("[MaxPhoneAccountSearch] MAX ограничил проверку номеров, пауза до #{until_time}")
    result(:paused, retry_at: until_time)
  end

  def remember(found:, chat_id: nil, max_name: nil)
    lookup = MaxPhoneLookup.find_or_initialize_by(phone: @phone)
    lookup.update!(found: found, chat_id: chat_id, max_name: max_name, checked_at: Time.current)
    from_lookup(lookup)
  end

  def from_lookup(lookup)
    result(lookup.found? ? :found : :not_found,
           chat_id: lookup.chat_id, name: lookup.max_name, checked_at: lookup.checked_at)
  end

  # Сбой сети или неожиданный ответ ничего не говорит о номере — не
  # запоминаем его и паузу не ставим.
  def failure(detail)
    Rails.logger.error("[MaxPhoneAccountSearch] #{@phone}: #{detail}")
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
