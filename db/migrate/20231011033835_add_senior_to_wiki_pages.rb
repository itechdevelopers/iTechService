class AddSeniorToWikiPages < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :senior, :boolean, default: false
  end
end
