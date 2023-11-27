class CreateReportCards < ActiveRecord::Migration[5.1]
  def change
    create_table :report_cards do |t|
      t.string :content
      t.integer :position
      t.references :report_column, foreign_key: true

      t.timestamps
    end
  end
end
