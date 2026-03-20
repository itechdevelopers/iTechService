class AddTelegramChatIdToKanbanBoards < ActiveRecord::Migration[5.1]
  def change
    add_reference :kanban_boards, :telegram_chat, foreign_key: true
  end
end
