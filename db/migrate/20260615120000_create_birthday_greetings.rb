class CreateBirthdayGreetings < ActiveRecord::Migration[5.1]
  def change
    create_table :birthday_greetings do |t|
      t.references :telegram_chat, foreign_key: true, null: true
      t.boolean :enabled,  null: false, default: false
      t.boolean :send_gif, null: false, default: true
      t.date    :last_run_on

      t.timestamps
    end

    create_table :birthday_greeting_variants do |t|
      t.references :birthday_greeting, foreign_key: true, null: false
      t.text :body, null: false

      t.timestamps
    end

    create_table :birthday_greeting_gifs do |t|
      t.references :birthday_greeting, foreign_key: true, null: false
      t.string :file

      t.timestamps
    end
  end
end
