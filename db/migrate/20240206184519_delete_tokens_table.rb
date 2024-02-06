class DeleteTokensTable < ActiveRecord::Migration[5.1]
  def up
    drop_table :tokens
  end

  def down
    create_table :tokens do |t|
      t.references :user, foreign_key: true
      t.references :signable, polymorphic: true
      t.string :token
      t.datetime :expires_at

      t.timestamps
      t.index :token, unique: true
    end
  end
end
