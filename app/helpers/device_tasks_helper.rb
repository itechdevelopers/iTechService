module DeviceTasksHelper
  def mac_service_helper_options
    users = User.helps_in_mac_service.in_city(current_city).to_a
    users << current_user unless users.include?(current_user)
    users
  end
end