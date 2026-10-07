# Кто начал диалог, если его начал сотрудник, а не клиент: по этому полю
# считается суточный лимит новых диалогов в MAX.
class AddStartedByToClientConversations < ActiveRecord::Migration[5.1]
  def change
    add_reference :client_conversations, :started_by, foreign_key: { to_table: :users }, index: true
  end
end
