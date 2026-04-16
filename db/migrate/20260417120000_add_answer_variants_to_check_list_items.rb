class AddAnswerVariantsToCheckListItems < ActiveRecord::Migration[5.1]
  def change
    add_column :check_list_items, :answer_variants, :text
  end
end
