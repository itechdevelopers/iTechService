class ServiceJobViewingPolicy < ApplicationPolicy
  def read?
    superadmin? || able_to?(:view_god_eye)
  end
end
