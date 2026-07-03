class UserSettings < ApplicationRecord
  belongs_to :user

  attribute :fixed_main_menu, :boolean, default: false
  attribute :auto_department_detection, :boolean, default: true
  attribute :receive_location_task_notifications, :boolean, default: true
  attribute :receive_glass_sticking_notifications, :boolean, default: true
  attribute :default_order_department_ids, :integer, array: true, default: []
  attribute :default_order_statuses, :string, array: true, default: []
end
