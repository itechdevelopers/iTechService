class CreateReportsBoards < ActiveRecord::Migration[5.1]
  def change
    create_table :reports_boards do |t|
      t.string :name
      t.string :description
      t.jsonb :cards

      t.timestamps
    end
  end
end
