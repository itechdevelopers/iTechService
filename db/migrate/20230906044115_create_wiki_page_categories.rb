class CreateWikiPageCategories < ActiveRecord::Migration[5.1]
  def change
    create_table :wiki_page_categories do |t|
      t.string :title
      t.timestamps
    end
  end
end
