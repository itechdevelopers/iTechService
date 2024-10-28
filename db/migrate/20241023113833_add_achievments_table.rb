class AddAchievmentsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :achievements do |t|
      t.string :name, null: false
      t.string :icon_mini
      t.string :icon

      t.timestamps
    end

    create_table :user_achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true
      t.text :comment
      t.datetime :achieved_at

      t.timestamps
    end

    add_index :user_achievements, %i[user_id achievement_id]
  end
end
