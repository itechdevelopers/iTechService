# frozen_string_literal: true

# Забор пакетов доступен водителям (основной сценарий) и админам.
# new? в ApplicationPolicy делегирует в create?.
class PackageWithdrawalPolicy < ApplicationPolicy
  def create?
    user.driver? || any_admin?
  end
end
