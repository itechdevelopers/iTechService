class MeritPolicy < ApplicationPolicy
  def read?
    same_department? && (create? || record.recipient_id == user.id)
  end

  def create?
    senior? || any_admin? || able_to?(:manage_merits)
  end

  def destroy?
    superadmin?
  end
end
