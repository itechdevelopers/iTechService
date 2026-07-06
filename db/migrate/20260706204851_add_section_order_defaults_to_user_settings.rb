class AddSectionOrderDefaultsToUserSettings < ActiveRecord::Migration[5.1]
  def change
    %w[spare_parts not_spare_parts archive].each do |section|
      add_column :user_settings, :"default_#{section}_department_ids", :integer, array: true, default: []
      add_column :user_settings, :"default_#{section}_statuses", :string, array: true, default: []
    end
  end
end
