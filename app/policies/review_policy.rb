class ReviewPolicy < ApplicationPolicy
  def read?
    user.able_to?(:show_reviews) || superadmin?
  end

  def manage?
    any_manager?
  end
end
