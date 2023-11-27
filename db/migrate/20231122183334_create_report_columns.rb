class CreateReportColumns < ActiveRecord::Migration[5.1]
  def change
    create_table :report_columns do |t|
      t.string :name
      t.references :reports_board, foreign_key: true

      t.timestamps
    end
  end
end
