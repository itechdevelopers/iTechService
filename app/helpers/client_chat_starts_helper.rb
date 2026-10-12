# frozen_string_literal: true

# Адреса модалки «Написать первым»: у каждого канала свой маршрут, а
# контроллер один — ClientChatStartsController.
module ClientChatStartsHelper
  CHAT_START_ROUTES = { 'max_phone' => 'max_chat', 'whatsapp' => 'whatsapp_chat' }.freeze

  def new_client_chat_start_path(client, channel)
    public_send("new_client_#{CHAT_START_ROUTES.fetch(channel)}_path", client)
  end

  def client_chat_start_path(client, channel)
    public_send("client_#{CHAT_START_ROUTES.fetch(channel)}_path", client)
  end
end
