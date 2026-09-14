class MoveClientConversationsToCity < ActiveRecord::Migration[5.1]
  # Диалог привязывается к городу, а не к филиалу: клиент выбирает город, и
  # выбрать за него один филиал из нескольких — произвол. Из филиала нужны были
  # только часы работы, а они у филиалов города совпадают.
  def up
    add_reference :client_conversations, :city, foreign_key: true

    # Перенос до удаления колонки — иначе связь потеряется безвозвратно.
    execute <<~SQL
      UPDATE client_conversations
         SET city_id = departments.city_id
        FROM departments
       WHERE departments.id = client_conversations.department_id
    SQL

    remove_reference :client_conversations, :department, foreign_key: true
  end

  def down
    add_reference :client_conversations, :department, foreign_key: true

    # Обратно — к любому реальному филиалу города: какой именно был, уже не узнать.
    execute <<~SQL
      UPDATE client_conversations
         SET department_id = (
               SELECT d.id FROM departments d
                WHERE d.city_id = client_conversations.city_id
                  AND d.role IN (0, 1, 3)
                  AND (d.archive = 'f' OR d.archive IS NULL)
                ORDER BY d.id ASC LIMIT 1
             )
    SQL

    remove_reference :client_conversations, :city, foreign_key: true
  end
end
