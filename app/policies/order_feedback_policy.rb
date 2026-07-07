class OrderFeedbackPolicy < ApplicationPolicy
  def update?
    superadmin? || same_department? ||
      able_to?(:view_feedback_notifications) ||
      (same_city? && able_to?(:view_feedbacks_in_city))
  end

  def edit?
    update?
  end

  def postpone?
    update?
  end

  class Scope < Scope
    def resolve
      if user.superadmin? || user.able_to?(:view_feedback_notifications)
        scope.all
      elsif user.able_to?(:view_feedbacks_in_city)
        department_ids = Department.where(city_id: user.city_id).select(:id)
        scope.where(order_id: Order.where(department_id: department_ids))
      else
        scope.where(order_id: Order.where(department_id: user.department_id))
      end
    end
  end
end
