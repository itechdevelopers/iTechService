class DeviceUnlockRequestPolicy < ApplicationPolicy
  # ТЗ: создавать запросы и менять статусы может «кто угодно» (любой
  # залогиненный сотрудник). Поэтому без superadmin/ability-гейтинга —
  # все действия открыты. Авторизация присутствия пользователя обеспечивается
  # на уровне ApplicationController (Devise authenticate_user!).
  def index?
    true
  end

  def show?
    true
  end

  # Иконка часов (history-экшен).
  def history?
    true
  end

  def new?
    true
  end

  def create?
    true
  end

  # Кастомный member-экшен — Pundit требует одноимённый предикат.
  def update_status?
    true
  end

  # Инлайн-добавление комментария из таблицы (member-экшен add_comment).
  def add_comment?
    true
  end

  def destroy?
    true
  end
end
