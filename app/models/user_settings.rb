class UserSettings < ApplicationRecord
  belongs_to :user

  attribute :fixed_main_menu, :boolean, default: false
  attribute :auto_department_detection, :boolean, default: true
  attribute :receive_location_task_notifications, :boolean, default: true
end
