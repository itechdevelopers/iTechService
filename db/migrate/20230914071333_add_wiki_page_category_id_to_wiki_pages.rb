class AddWikiPageCategoryIdToWikiPages < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :wiki_page_category_id, :integer
  end
end
