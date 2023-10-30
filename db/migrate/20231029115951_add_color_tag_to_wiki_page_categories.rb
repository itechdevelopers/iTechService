class AddColorTagToWikiPageCategories < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_page_categories, :color_tag, :string, default: "ffffff"
  end
end
