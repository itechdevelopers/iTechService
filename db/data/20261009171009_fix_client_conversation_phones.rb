# Две починки данных диалогов с клиентами.
#
# 1. MAX присылал вместо скрытого номера 0, и он сохранялся как телефон
#    диалога — карточка показывала «Телефон: 0». Номер на самом деле неизвестен.
# 2. Диалоги с известным номером, но без карточки клиента: номер пришёл уже в
#    открытый диалог (он начался с ответа с телефона) или в карточке клиента
#    номер записан иначе (+7…, 8…, со скобками). Такие диалоги не видны в
#    карточке клиента — привязываем их тем же поиском, что теперь работает
#    вживую. Диалоги, где привязку уже трогал сотрудник (служебные строки
#    «Клиент привязан / отвязан / изменён»), не трогаем: его решение важнее.
class FixClientConversationPhones < ActiveRecord::Migration[5.1]
  def up
    ClientConversation.where(contact_phone: '0').update_all(contact_phone: nil)

    touched = ClientMessage.where(kind: 'system').where("body LIKE 'Клиент %'").select(:client_conversation_id)
    ClientConversation.where(client_id: nil)
                      .where("contact_phone ~ '^[0-9]{11,12}$'")
                      .where.not(id: touched)
                      .find_each { |conversation| conversation.identify_by_phone(conversation.contact_phone) }
  end

  # Откатывать нечего: «0» номером не был, а привязку при необходимости
  # снимает сотрудник в карточке диалога.
  def down; end
end
