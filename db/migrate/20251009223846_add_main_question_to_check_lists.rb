class AddMainQuestionToCheckLists < ActiveRecord::Migration[5.1]
  def change
    add_reference :check_lists, :main_question, foreign_key: { to_table: :check_list_items }, index: true
  end
end
