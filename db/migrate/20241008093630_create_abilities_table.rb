class CreateAbilitiesTable < ActiveRecord::Migration[5.1]
  def up
    create_table :abilities do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :user_abilities do |t|
      t.references :user, foreign_key: true
      t.references :ability, foreign_key: true
      t.timestamps
    end

    add_index :abilities, :name, unique: true
    add_index :user_abilities, %i[user_id ability_id], unique: true
  end

  def down
    drop_table :user_abilities
    drop_table :abilities
  end
end
