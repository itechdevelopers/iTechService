class AddImagesToWikiPages < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :images, :string, array: true, default: []
  end
end
