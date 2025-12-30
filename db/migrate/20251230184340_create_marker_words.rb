class CreateMarkerWords < ActiveRecord::Migration[5.1]
  def change
    create_table :marker_words do |t|
      t.string :word, null: false

      t.timestamps
    end
    add_index :marker_words, :word, unique: true
  end
end
