class CreateRecordEditsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :record_edits do |t|
      t.references :user
      t.references :editable, polymorphic: true

      t.timestamps
    end
  end
end
