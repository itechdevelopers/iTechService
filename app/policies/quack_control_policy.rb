# frozen_string_literal: true

# Headless policy для страницы «Кря-контроль».
# Доступ: технари (роль technician), сидящие на любой ремонтной локации,
# плюс супер-админы. Намеренно НЕ через DB-Ability.
class QuackControlPolicy < ApplicationPolicy
  def show?
    (user.technician? && user.location&.is_any_repair?) || superadmin?
  end
end
