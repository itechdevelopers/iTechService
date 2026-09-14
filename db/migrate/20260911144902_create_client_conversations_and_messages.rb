class CreateClientConversationsAndMessages < ActiveRecord::Migration[5.1]
  def change
    create_table :client_conversations do |t|
      t.string     :channel, null: false, default: 'telegram'
      t.string     :external_chat_id, null: false # id чата на стороне мессенджера
      t.references :client,        foreign_key: true # если клиента удалось опознать
      t.references :department,    foreign_key: true # чьи рабочие часы цитирует автоответ
      t.references :assigned_user, foreign_key: { to_table: :users } # кто ведёт диалог
      t.references :closed_by,     foreign_key: { to_table: :users } # пусто ⇒ закрыт автоматически
      t.string     :status, null: false, default: 'open'
      t.string     :contact_name     # имя из профиля мессенджера
      t.string     :contact_username # @ник
      t.string     :contact_phone    # если клиент поделился контактом
      t.datetime   :started_at       # первое входящее — точка отсчёта длительности
      t.datetime   :first_reply_at   # первый ответ живого сотрудника
      t.datetime   :last_message_at  # любое сообщение — для сортировки списка
      t.datetime   :last_inbound_at  # последнее от клиента
      t.datetime   :last_reply_at    # последний ответ ЖИВОГО сотрудника
      t.datetime   :closed_at
      t.datetime   :auto_reply_sent_at # антиспам автоответа вне рабочих часов

      t.timestamps
    end

    # Индекс частичный: у одного чата за год копятся десятки закрытых диалогов,
    # а открытый может быть ровно один. Полный unique запретил бы второй диалог
    # с тем же клиентом — и длительность растянулась бы на месяцы.
    add_index :client_conversations, %i[channel external_chat_id],
              unique: true, where: "status = 'open'",
              name: 'index_client_conversations_on_open_chat'
    add_index :client_conversations, %i[status last_message_at]

    create_table :client_messages do |t|
      t.references :client_conversation, null: false, foreign_key: true
      t.string     :direction, null: false        # in / out
      t.references :user, foreign_key: true       # автор исходящего; пусто у входящих и автоответов
      t.text       :body
      t.string     :external_id                   # message_id в мессенджере
      t.string     :kind, null: false, default: 'text' # text / photo / system
      t.string     :photo
      t.string     :delivery_status, null: false, default: 'pending' # pending / sent / failed
      t.text       :delivery_error
      t.datetime   :sent_at

      t.timestamps
    end

    add_index :client_messages, %i[client_conversation_id created_at]
    # Дедупликация повторной доставки: мессенджер пере-шлёт апдейт, если вебхук
    # не ответил вовремя, а id сообщения при этом не меняется. У исходящих
    # external_id заполняется только после успешной отправки, поэтому индекс
    # частичный — иначе вторая pending-запись упёрлась бы в NULL-коллизию.
    add_index :client_messages, %i[client_conversation_id external_id],
              unique: true, where: 'external_id IS NOT NULL',
              name: 'index_client_messages_on_conversation_and_external_id'
  end
end
