class ClientRequestPolicy < ApplicationPolicy
  def index?
    permitted?
  end

  def show?
    permitted?
  end

  def create?
    permitted?
  end

  def new?
    create?
  end

  def update?
    permitted?
  end

  def edit?
    update?
  end

  # Кастомный member-экшен — Pundit требует одноимённый предикат.
  def update_status?
    update?
  end

  def destroy?
    superadmin?
  end

  private

  # Доступ к функционалу запросов: суперадмин ∪ сотрудник с галочкой ability.
  # Тот же набор, что и адресаты уведомлений (план §5).
  def permitted?
    superadmin? || able_to?(:work_with_receipt_search_requests)
  end
end
