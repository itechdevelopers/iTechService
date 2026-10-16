# frozen_string_literal: true

# Headless policy для страницы «Кря-контроль».
# Доступ: любой сотрудник, сидящий на любой ремонтной локации (вне зависимости
# от роли), плюс супер-админы. Намеренно НЕ через DB-Ability.
class QuackControlPolicy < ApplicationPolicy
  def show?
    user.location&.is_any_repair? || superadmin?
  end

  # Убрать работу из счёта сотрудника (QuackControlController#exclude).
  def exclude?
    superadmin?
  end
end
