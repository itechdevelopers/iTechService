class PersonnelRepairsPolicy < ApplicationPolicy
  def show?
    user.present?
  end
end
