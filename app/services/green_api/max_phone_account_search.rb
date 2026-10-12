# frozen_string_literal: true

module GreenApi
  # Поиск в MAX: аккаунт — checkAccount (номер числом), имя — из профиля. По
  # имени сотрудник видит, кому пишет: номер в базе мог давно перейти к
  # другому человеку.
  class MaxPhoneAccountSearch < AccountSearch
    CHANNEL = 'max_phone'

    private

    def check_account
      response = post('checkAccount', phoneNumber: @phone.to_i)
      return pause! if limited?(response)
      return failure("checkAccount: HTTP #{response.code}") unless response.code == 200 && body(response).key?('exist')

      chat_id = body(response)['chatId'].to_s
      if body(response)['exist'] == true && chat_id.present?
        remember(found: true, chat_id: chat_id, name: profile_name(chat_id))
      else
        remember(found: false)
      end
    end

    # Без имени поиск всё равно удался.
    def profile_name(chat_id)
      response = post('getContactInfo', chatId: chat_id)
      pause! if limited?(response)
      response.code == 200 ? body(response)['name'].to_s.strip.presence : nil
    rescue StandardError => e
      Rails.logger.warn("[#{self.class.name}] getContactInfo: #{e.class}: #{e.message}")
      nil
    end
  end
end
