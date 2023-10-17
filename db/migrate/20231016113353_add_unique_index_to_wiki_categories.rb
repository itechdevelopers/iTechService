class AddUniqueIndexToWikiCategories < ActiveRecord::Migration[5.1]  
  def up
    execute <<~SQL
    UPDATE wiki_pages
    SET wiki_page_category_id = 
    (SELECT id FROM wiki_page_categories WHERE title =
    (SELECT title FROM wiki_page_categories WHERE id = wiki_page_category_id)
    ORDER BY id ASC LIMIT 1);
    DELETE FROM wiki_page_categories WHERE id NOT IN
    (SELECT wiki_page_category_id FROM wiki_pages);
    SQL

    add_index :wiki_page_categories, :title, unique: true
  end

  def down
    remove_index :wiki_page_categories, :title
  end
end
