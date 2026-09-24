class WeeklyMarkupDashboardPolicy < ApplicationPolicy
  def show?
    superadmin?
  end

  alias index? show?
  alias details? show?
  alias iphone_sales? show?
  alias activity_counts? show?
  alias branch? show?
  alias download? show?
end
