class AddPrivateToWikiPages < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :private, :boolean
  end
end
