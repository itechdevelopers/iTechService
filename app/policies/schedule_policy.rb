class SchedulePolicy < ApplicationPolicy
  def index?
    superadmin? || able_to?(:manage_schedule)
  end
end
