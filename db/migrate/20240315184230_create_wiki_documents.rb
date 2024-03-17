class CreateWikiDocuments < ActiveRecord::Migration[5.1]
  def change
    create_table :wiki_documents do |t|
      t.references :wiki_page, foreign_key: true
      t.string :file

      t.timestamps
    end
  end
end
