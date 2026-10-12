class TelephonyDirectoryPolicy < ApplicationPolicy
  def index?
    PhoneCallPolicy.new(user, PhoneCall).index?
  end
  def manage?
    !user.is_fired? && any_admin?
  end
end
