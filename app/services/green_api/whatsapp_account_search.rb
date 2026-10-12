# frozen_string_literal: true

module GreenApi
  # Поиск в WhatsApp — checkWhatsapp.
  #
  # Чат — номер@c.us, а не chatId из ответа: там анонимный lid, а уведомления
  # о сообщениях приходят с номер@c.us. Диалог, заведённый на lid, не совпал
  # бы с ответом клиента, и тот открыл бы второй диалог.
  #
  # Имя профиля WhatsApp отдаёт, только если человек уже писал на этот номер,
  # а такого человека находит и поиск по прежним диалогам, — поэтому за
  # именем не ходим.
  class WhatsappAccountSearch < AccountSearch
    CHANNEL = 'whatsapp'

    private

    def check_account
      response = post('checkWhatsapp', chatId: @phone)
      return pause! if limited?(response)
      unless response.code == 200 && body(response).key?('existsWhatsapp')
        return failure("checkWhatsapp: HTTP #{response.code}")
      end

      body(response)['existsWhatsapp'] == true ? remember(found: true, chat_id: "#{@phone}@c.us") : remember(found: false)
    end
  end
end
