class WeeklyMarkupDashboardPolicy < ApplicationPolicy
  def show?
    superadmin?
  end

  alias index? show?
  alias details? show?
  alias branch? show?
  alias download? show?
end
