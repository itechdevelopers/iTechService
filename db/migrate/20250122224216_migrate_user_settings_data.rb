class MigrateUserSettingsData < ActiveRecord::Migration[5.1]
  def up
    User.find_each do |user|
      UserSettings.create!(
        user: user,
        fixed_main_menu: user.fixed_main_menu,
        auto_department_detection: true
      )
    end

    remove_column :users, :fixed_main_menu
  end

  def down
    add_column :users, :fixed_main_menu, :boolean, default: false

    UserSettings.find_each do |settings|
      settings.user.update_column(:fixed_main_menu, settings.fixed_main_menu)
    end
  end
end
