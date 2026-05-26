class PersonnelStatisticsPolicy < ApplicationPolicy
  def show?
    user.present?
  end
end
