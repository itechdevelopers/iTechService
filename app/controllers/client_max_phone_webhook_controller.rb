# frozen_string_literal: true

# Уведомления от аккаунта MAX, на номер которого пишут клиенты (канал
# max_phone). Разбор общий для GREEN-API — см. ClientGreenApiWebhookController.
class ClientMaxPhoneWebhookController < ClientGreenApiWebhookController
  CHANNEL = 'max_phone'
  # Окончательные отказы, о которых GREEN-API узнаёт уже после того, как
  # принял сообщение.
  FAILED_STATUSES = {
    'failed' => 'MAX не принял сообщение',
    'noAccount' => 'у получателя нет аккаунта MAX'
  }.freeze

  private

  # У групп MAX id чата отрицательный.
  def personal_chat?
    chat_id.present? && !chat_id.start_with?('-') &&
      params.dig(:senderData, :chatType).to_s.in?(['', 'user'])
  end

  # Номер MAX присылает отдельным полем; если человек скрыл его настройками
  # приватности — нулём, который ClientChat::Phone номером не считает.
  def sender_phone
    ClientChat::Phone.normalize(params.dig(:senderData, :senderPhoneNumber))
  end
end
