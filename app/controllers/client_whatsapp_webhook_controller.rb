# frozen_string_literal: true

# Уведомления от аккаунта WhatsApp, на номер которого пишут клиенты (канал
# whatsapp). Разбор общий для GREEN-API — см. ClientGreenApiWebhookController.
#
# Id чата в WhatsApp — номер с суффиксом: 79001234567@c.us. WhatsApp
# постепенно прячет номера, и человек, скрывший свой, приходит с анонимным
# id вида 123456789@lid — это тоже личный чат, только опознать клиента по
# нему нельзя, его привязывают руками.
class ClientWhatsappWebhookController < ClientGreenApiWebhookController
  CHANNEL = 'whatsapp'
  PERSONAL_SUFFIXES = %w[@c.us @lid].freeze
  PHONE_SUFFIX = '@c.us'
  UNSUPPORTED = ClientGreenApiWebhookController::UNSUPPORTED.merge('contactsArrayMessage' => 'контакты').freeze
  # Окончательные отказы, о которых GREEN-API узнаёт уже после того, как
  # принял сообщение. suspended — WhatsApp на время ограничил отправку с
  # номера (yellowCard — прежнее имя того же).
  FAILED_STATUSES = {
    'failed' => 'WhatsApp не принял сообщение',
    'noAccount' => 'у получателя нет WhatsApp',
    'suspended' => 'WhatsApp временно ограничил отправку с номера',
    'yellowCard' => 'WhatsApp временно ограничил отправку с номера'
  }.freeze

  private

  # Группы (@g.us), рассылки и статусы (@broadcast), каналы (@newsletter) к
  # диалогам с клиентами не относятся.
  def personal_chat?
    chat_id.end_with?(*PERSONAL_SUFFIXES)
  end

  # Отдельного поля с номером у WhatsApp нет: номер — это id личного чата.
  def sender_phone
    return unless chat_id.end_with?(PHONE_SUFFIX)

    ClientChat::Phone.normalize(chat_id.delete_suffix(PHONE_SUFFIX))
  end
end
