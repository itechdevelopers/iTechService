class CreateUserSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :user_settings do |t|
      t.references :user, foreign_key: true, null: false
      t.boolean :fixed_main_menu, default: false, null: false
      t.boolean :auto_department_detection, default: true, null: false

      t.timestamps
    end
  end
end
