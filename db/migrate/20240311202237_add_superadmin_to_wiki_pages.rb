class AddSuperadminToWikiPages < ActiveRecord::Migration[5.1]
  def change
    add_column :wiki_pages, :superadmin, :boolean, default: false
  end
end
