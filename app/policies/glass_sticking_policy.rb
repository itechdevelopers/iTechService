class GlassStickingPolicy < ApplicationPolicy
  def show?
    user.present? && (superadmin? || user.has_role?('engraver') || able_to?(:glass_sticking))
  end

  def recipients?
    show?
  end

  def notify?
    show?
  end
end
